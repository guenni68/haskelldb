-----------------------------------------------------------
-- |
-- Module      :  HDBRec
-- Copyright   :  HWT Group (c) 2003, haskelldb-users@lists.sourceforge.net
-- License     :  BSD-style
-- 
-- Maintainer  :  haskelldb-users@lists.sourceforge.net
-- Stability   :  experimental
-- Portability :  non-portable
-- 
-- This is a replacement for some of TREX.
--
-- $Revision: 1.33 $
-----------------------------------------------------------
module Database.HaskellDB.HDBRec 
    (
    -- * Record types
    RecNil(..), RecCons(..), Record
    -- * Record construction
    , emptyRecord, (.=.), ( # )
    -- * Labels
    , FieldTag(..)
    -- * Record predicates and operations
    , HasField, Select(..), SetField, setField
    -- * Showing and reading records
    , ShowRecRow(..), ReadRecRow(..)
    ) where

import Data.List

infixr  5 #
infix   6 .=.

-- | The empty record.
data RecNil = RecNil deriving (Eq, Ord)

-- | Constructor that adds a field to a record.
-- f is the field tag, a is the field value and b is the rest of the record.
data RecCons f a b = RecCons a b deriving (Eq, Ord)

-- | The type used for records. This is a function
--   that takes a 'RecNil' so that the user does not have to 
--   put a 'RecNil' at the end of every record.
type Record r = RecNil -> r

-- * Record construction


-- | Creates one-field record from a label and a value
( .=. ) :: l f a         -- ^ Label
       -> a              -- ^ Value
       -> Record (RecCons f a RecNil)  -- ^ New record
_ .=. x = RecCons x

-- | Adds the field from a one-field record to another record.
( # ) :: Record (RecCons f a RecNil) -- ^ Field to add
      -> (b -> c)                    -- ^ Rest of record
      -> (b -> RecCons f a c)        -- ^ New record
f # r = let RecCons x _ = f RecNil in RecCons x . r


-- | The empty record
emptyRecord :: Record RecNil
emptyRecord = id

-- * Class definitions.

-- | Class for field labels.
class FieldTag f where
    -- | Gets the name of the label.
    fieldName :: f -> String


-- | The record @r@ has the field @f@ if there is an instance of
--   @HasField f r@.
class HasField f r
instance HasField f (RecCons f a r)
instance HasField f r => HasField f (RecCons g a r)
instance HasField f r => HasField f (Record r)

-- * Record concatenation

class RecCat r1 r2 r3 | r1 r2 -> r3 where
    -- | Concatenates two records.
    cat :: r1 -> r2 -> r3

instance RecCat RecNil r r where
    cat RecNil r = r

instance RecCat r1 r2 r3 => RecCat (RecCons f a r1) r2 (RecCons f a r3) where
    cat (RecCons x r1) r2 = RecCons x (cat r1 r2)

instance RecCat r1 r2 r3 => RecCat (Record r1) (Record r2) (Record r3) where
    cat r1 r2 = \n -> cat (r1 n) (r2 n)

-- * Field selection

infix   9 !

class Select f r a | f r -> a where
    -- | Field selection operator. It is overloaded so that
    --   users (read HaskellDB) can redefine it for things
    --   with phantom record types.
    (!) :: r -> f -> a

instance SelectField f r a => Select (l f a) (Record r) a where
    r ! (_::l f a) = selectField (undefined::f) r

-- | Class which does the actual work of 
--   getting the value of a field from a record.
-- FIXME: would like the dependency f r -> a here, but
-- that makes Hugs complain about conflicting instaces
class SelectField f r a where
    -- | Gets the value of a field from a record.
    selectField :: f -- ^ Field label
		-> r -- ^ Record 
		-> a -- ^ Field value

instance SelectField f (RecCons f a r) a where
    selectField _ (RecCons x _) = x

instance SelectField f r a => SelectField f (RecCons g b r) a where
    selectField f (RecCons _ r) = selectField f r

instance SelectField f r a => SelectField f (Record r) a where
    selectField f r = selectField f (r RecNil)

-- * Field update

setField :: SetField f r a => l f a -> a -> r -> r
setField (_::l f a) = setField_ (undefined::f)

class SetField f r a where
    -- | Sets the value of a field in a record.
    setField_ :: f -- ^ Field label
	     -> a -- ^ New field value
	     -> r -- ^ Record
	     -> r -- ^ New record

instance SetField f (RecCons f a r) a where
    setField_  _ y (RecCons _ r) = RecCons y r

instance SetField f r a => SetField f (RecCons g b r) a where
    setField_ l y (RecCons f r) = RecCons f (setField_ l y r)

instance SetField f r a => SetField f (Record r) a where
    setField_ f y r = \e -> setField_ f y (r e)

-- * Equality and ordering

instance Eq r => Eq (Record r) where
    r1 == r2 = r1 RecNil == r2 RecNil

instance Ord r => Ord (Record r) where
    r1 <= r2 = r1 RecNil <= r2 RecNil

-- * Showing rows 

-- | Get the label name of a record entry.
consFieldName :: FieldTag f => RecCons f a r -> String
consFieldName (_::RecCons f a r) = fieldName (undefined::f)

-- | Convert a record to a list of label names and field values.
class ShowRecRow r where
    showRecRow :: r -> [(String,ShowS)]

-- Last entry in each record will terminate the ShowrecRow recursion.
instance ShowRecRow RecNil where
    showRecRow _ = []

-- Recurse a record and produce a showable tuple.
instance (FieldTag a, 
	  Show b, 
	  ShowRecRow c) => ShowRecRow (RecCons a b c) where
    showRecRow r@(RecCons x fs) = (consFieldName r, shows x) : showRecRow fs

instance ShowRecRow r => ShowRecRow (Record r) where
    showRecRow r = showRecRow (r RecNil)



instance Show r => Show (Record r) where
    showsPrec x r = showsPrec x (r RecNil)

-- probably not terribly efficient
showsShowRecRow :: ShowRecRow r => r -> ShowS 
showsShowRecRow r = shows $ [(f,v "") | (f,v) <- showRecRow r]

instance Show RecNil where
    showsPrec _ r = showsShowRecRow r

instance  (FieldTag a, Show b, ShowRecRow c) => Show (RecCons a b c) where
    showsPrec _ r = showsShowRecRow r


-- * Reading rows

class ReadRecRow r where
    -- | Convert a list of labels and strins representating values
    --   to a record.
    readRecRow :: [(String,String)] -> [(r,[(String,String)])]

instance ReadRecRow RecNil where
    readRecRow xs = [(RecNil,xs)]

instance (FieldTag a, 
	  Read b, 
	  ReadRecRow c) => ReadRecRow (RecCons a b c) where
    readRecRow [] = []
    readRecRow xs = let res = readRecEntry xs (fst $ head res) in res

readRecEntry :: (Read a, FieldTag f, ReadRecRow r) => 
		[(String,String)] 
	     -> RecCons f a r   -- ^ Dummy to get return type right
	     -> [(RecCons f a r,[(String,String)])]
readRecEntry ((f,v):xs) r | f == consFieldName r = res
			  | otherwise = []
    where
    res = [(RecCons x r, xs') | (x,"") <- reads v, 
	   (r,xs') <- readRecRow xs]


readsReadRecRow :: ReadRecRow r => ReadS r
readsReadRecRow s = [(r,"") | (l,"") <- reads s, (r,[]) <- readRecRow l]

instance ReadRecRow r => Read (Record r) where
    readsPrec _ s = [(const r, rs) | (r,rs) <- readsReadRecRow s]

instance Read RecNil where
   readsPrec _ = readsReadRecRow

instance (FieldTag a, Read b, ReadRecRow c) => Read (RecCons a b c) where
    readsPrec _ s = readsReadRecRow s
