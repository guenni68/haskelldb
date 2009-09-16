-----------------------------------------------------------
-- |
-- Module      :  Database
-- Copyright   :  Daan Leijen (c) 1999, daan@cs.uu.nl
--                HWT Group (c) 2003, haskelldb-users@lists.sourceforge.net
-- License     :  BSD-style
-- 
-- Maintainer  :  haskelldb-users@lists.sourceforge.net
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Defines standard database operations and the
-- primitive hooks that a particular database binding
-- must provide.
--
-- 
-----------------------------------------------------------
module Database.HaskellDB.Database ( 
		-- * Type declarations
		  Database(..)
		, GetRec(..), GetInstances(..)
                , GetNullable'(..)

		-- * Function declarations
		, query
		, insert, insertOpt, delete, update, insertQuery
		, tables, describe, transaction
		, createDB, createTable, dropDB, dropTable
		, getNullable
		) where

import Database.HaskellDB.FieldType
import Database.HaskellDB.PrimQuery
import Database.HaskellDB.Optimize (optimize, optimizeCriteria)
import Database.HaskellDB.Query	
import Database.HaskellDB.BoundedString
import Database.HaskellDB.BoundedList
import Data.HList.FakePrelude

import System.Time
import Control.Monad

data Database
	= Database  
	  { dbQuery  :: forall er vr. GetRec er vr => 
	     PrimQuery 
	     -> Rel (Record er)
	     -> IO [Record vr]
  	  , dbInsert :: TableName -> Assoc -> IO ()
	  , dbInsertQuery :: TableName -> PrimQuery -> IO ()
  	  , dbDelete :: TableName 
                     -> [PrimExpr] -- Conditions which must all be true for a
                                   -- row to be deleted.
                     -> IO ()
  	  , dbUpdate :: TableName 
                     -> [PrimExpr] -- Conditions which must all be true for a row
                                   --   to be updated.
                     -> Assoc -- New values for some fields.
                     -> IO ()
	  , dbTables :: IO [TableName]
	  , dbDescribe :: TableName -> IO [(Attribute,FieldDesc)]
	  , dbTransaction :: forall a. IO a -> IO a
	  , dbCreateDB :: String -> IO ()
	  , dbCreateTable :: TableName -> [(Attribute,FieldDesc)] -> IO ()
	  , dbDropDB :: String -> IO ()
	  , dbDropTable :: TableName -> IO ()
  	  }


--
-- Creating result records
-- 	 

-- | Functions for getting values of a given type. Database drivers
--   need to implement these functions and pass this record to 'getRec'
--   when getting query results.
--
--   All these functions should return 'Nothing' if the value is NULL.
data GetInstances s = 
    GetInstances {
		 -- | Get a 'String' value.
		 getString       :: s -> String -> IO (Maybe String)
		 -- | Get an 'Int' value.
	       , getInt          :: s -> String -> IO (Maybe Int)
		 -- | Get an 'Integer' value.
	       , getInteger      :: s -> String -> IO (Maybe Integer)
		 -- | Get a 'Double' value. 
	       , getDouble       :: s -> String -> IO (Maybe Double)
		 -- | Get a 'Bool' value.
	       , getBool :: s -> String -> IO (Maybe Bool)
		 -- | Get a 'CalendarTime' value.
	       , getCalendarTime :: s -> String -> IO (Maybe CalendarTime)
	       }


class GetRec er vr | er -> vr, vr -> er where
    -- | Create a result record.
    getRec :: GetInstances s  -- ^ Driver functions for getting values
			      --   of different types.
	   -> Rel (Record er) -- ^ Phantom argument to the the return type right
	   -> Scheme       -- ^ Fields to get.
	   -> s            -- ^ Driver-specific result data 
	                   --   (for example a Statement object)
           -> IO (Record vr)        -- ^ Result record.

instance GetRec HNil HNil where
    -- NOTE: we accept extra fields, since the hacks in Optimize could add fields that we don't want
    getRec _ _ _ _ = return emptyRecord

instance (GetValue a, GetRec er vr, HExtend (LVPair f a) (Record vr) (Record (HCons (LVPair f a) vr)))
    => GetRec (HCons (LVPair f (Expr a)) er) (HCons (LVPair f a) vr) where

    getRec _ _ [] _ = fail $ "Wanted non-empty record, but scheme is empty"
    getRec vfs c (f:fs) stmt = 
	do
	x <- getValue vfs stmt f
	r <- getRec vfs (recTailType c) fs stmt
	return (LVPair x .*. r)

recTailType :: Rel (Record (HCons (LVPair f (Expr a)) er)) -> Rel (Record er)
recTailType _ = undefined

class GetValue a where
    getValue :: GetInstances s -> s -> String -> IO a

-- these are silly, there's probably a cleaner way to do this,
-- but instance GetValue (Maybe a) => GetValue a doesn't work
-- Maybe we could do it the other way around.
instance GetValue String where getValue = getNonNull
instance GetValue Int where getValue = getNonNull
instance GetValue Integer where getValue = getNonNull
instance GetValue Double where getValue = getNonNull
instance GetValue Bool where getValue = getNonNull
instance GetValue CalendarTime where getValue = getNonNull
instance Size n => GetValue (BoundedString n) where getValue = getNonNull

instance GetValue (Maybe String) where getValue = getString
instance GetValue (Maybe Int) where getValue = getInt
instance GetValue (Maybe Integer) where getValue = getInteger
instance GetValue (Maybe Double) where getValue = getDouble
instance GetValue (Maybe Bool) where getValue = getBool
instance GetValue (Maybe CalendarTime) where getValue = getCalendarTime
instance Size n => GetValue (Maybe (BoundedString n)) where 
    getValue fs s f = liftM (liftM trunc) (getValue fs s f)

-- | Get a non-NULL value. Fails if the value is NULL.
getNonNull :: GetValue (Maybe a) => GetInstances s -> s -> String -> IO a
getNonNull fs s f = 
	do
	m <- getValue fs s f
	case m of
	       Nothing -> fail $ "Got NULL value from non-NULL field " ++ f
	       Just v -> return v
	  

-----------------------------------------------------------
-- Database operations
-----------------------------------------------------------  	    	  

-- | performs a query on a database
query :: GetRec er vr => Database -> Query (Rel (Record er)) -> IO [Record vr]
query db q = dbQuery db (optimize primQuery) rel
    where (primQuery,rel) = runQueryRel q
	
-- | Inserts values from a query into a table
insertQuery :: Database -> Table r -> Query (Rel r) -> IO ()
insertQuery db (Table name assoc) q
	= dbInsertQuery db name (optimize (runQuery q))



-- | Inserts a record into a table
insert :: (RecordLabels er ls, HLabelSet ls, HRearrange ls r r', RecordValues r' vs',
           HMapOut ToPrimExprsOp vs' PrimExpr, InsertRec r' er) =>
    Database -> Table (Record er) -> Record r -> IO ()
insert db t@(Table name assoc) newrec = dbInsert db name (zip (attrs assoc) (exprs newrec'))
    where
      attrs   = map (\(attr,AttrExpr name) -> name)
      newrec' = hRearrange (recordLabels (tableRec t)) newrec


-- getNullable strips any fields of a record which are non-Maybe types,
-- and replaces all the Maybe values with Nothing.
-- For example: getNullable (x .=. 3 .*. y .=. Just "a" .*. emptyRecord) returns
--                          (y .=. Nothing .*. emptyRecord)
-- Used in insertOpt
getNullable :: (FromHJust b r', HMap GetNullableOp r b) => Record r -> Record r'
getNullable (Record r) = Record . fromHJust . hMap GetNullableOp $ r

class NullableExpr a b | a -> b
instance TypeCast f HTrue => NullableExpr (LVPair l (Expr (Maybe a))) f
instance TypeCast f HFalse => NullableExpr a f

data GetNullableOp = GetNullableOp
instance (NullableExpr a f, GetNullable' f a r) => Apply GetNullableOp a r where
    apply _ a = getNullable' (undefined :: f) a

class GetNullable' f a r | f a -> r where
    getNullable' :: f -> a -> r
instance GetNullable' HTrue
                      (LVPair l (Expr (Maybe a)))
                      (HJust (LVPair l (Maybe a))) where
    getNullable' _ _ = HJust $ LVPair Nothing
instance GetNullable' HFalse a HNothing where
    getNullable' _ _ = HNothing



-- | Inserts a record into a table. Values can be omitted for Maybe columns, they will
--   default to Nothing.
insertOpt :: (RecordLabels er ls,
        HLabelSet ls,
        HRearrange ls r' r'',
        RecordValues r'' vs'',
        HMapOut ToPrimExprsOp vs'' PrimExpr,
        HLeftUnion (Record r) (Record nrc) (Record r'),
        InsertRec r'' er,
        FromHJust nrj nr,
        HMap GetNullableOp er nrj,
        HMap ConstantRecordOp nr nrc) =>
    Database -> Table (Record er) -> Record r -> IO ()
insertOpt db t newrec = insert db t (newrec `hLeftUnion` constantRecord defaultNulls)
    where
      defaultNulls = getNullable $ tableRec t

-- | deletes a bunch of records	  
delete :: Database -- ^ The database
       -> Table r -- ^ The table to delete records from
       -> (Rel r -> Expr Bool) -- ^ Predicate used to select records to delete
       -> IO ()
delete db (Table name assoc) criteria = dbDelete db name cs
	where
	  (Expr primExpr)  = criteria rel
          cs               = optimizeCriteria [substAttr assoc primExpr]
	  rel		   = Rel 0 (map fst assoc)
	  
-- | Updates records
update :: (HMapOut ShowLabelsOp ls String, RecordLabels s ls, HMapOut ToPrimExprsOp svs PrimExpr, RecordValues s svs) =>
          Database                -- ^ The database
          -> Table r              -- ^ The table to update
          -> (Rel r -> Expr Bool) -- ^ Predicate used to select records to update
          -> (Rel r -> Record s)  -- ^ Function used to modify selected records
          -> IO ()
update db (Table name assoc) criteria assignFun = dbUpdate db name cs newassoc
	where
	  (Expr primExpr)= criteria rel
          cs = optimizeCriteria [substAttr assoc primExpr]
	  	
	  newassoc	= zip (map subst (labels assigns))
	  		      (exprs assigns)
	  		      
	  subst label	= case (lookup label assoc) of
	  		    (Just (AttrExpr name)) -> name
	  		    (Nothing)		   -> error ("Database.update: attribute '" 
	  		    				     ++ label ++ "' is not in database '" ++ name ++ "'")
	  	
	  assigns	= assignFun rel
	  rel		= Rel 0 (map fst assoc)
	
-- | List all tables in the database
tables :: Database  -- ^ Database
       -> IO [TableName]  -- ^ Names of all tables in the database
tables = dbTables

-- | List all columns in a table, along with their types
describe :: Database  -- ^ Database
	 -> TableName       -- ^ Name of the tables whose columns are to be listed
	 -> IO [(Attribute,FieldDesc)] -- ^ Name and type info for each column
describe = dbDescribe


-- | Performs some database action in a transaction. If no exception is thrown,
--   the changes are committed. 
transaction :: Database -- ^ Database
	    -> IO a -- ^ Action to run
	    -> IO a 
transaction = dbTransaction

-----------------------------------------------------------
-- Functions that edit the database layout
-----------------------------------------------------------
-- | Is not very useful. You need to be root to use it. 
--   We suggest you solve this in another way
createDB :: Database -- ^ Database
	 -> String -- ^ Name of database to create 
	 -> IO ()
createDB = dbCreateDB

createTable :: Database -- ^ Database
	    -> TableName -- ^ Name of table to create 
	    -> [(Attribute,FieldDesc)] -- ^ The fields of the table
	    -> IO ()
createTable = dbCreateTable

dropDB :: Database -- ^ Database
       -> String -- ^ Name of database to drop
       -> IO ()
dropDB = dbDropDB

dropTable :: Database -- ^ Database
	  -> TableName -- ^ Name of table to drop
	  -> IO ()
dropTable = dbDropTable
