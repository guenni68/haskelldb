-----------------------------------------------------------
-- Daan Leijen (c) 1999, daan@cs.uu.nl
--
-- module PrimQuery:
-- 	defines the datatype of relational expressions (PrimQuery)
-- 	and some useful functions on PrimQuery's.
-----------------------------------------------------------
module PrimQuery where

import PPrint
import List ((\\))

-----------------------------------------------------------
-- assertions
-----------------------------------------------------------
assert moduleName functionName msg test x
 	| test      = x
        | otherwise = error ("assert: " ++ moduleName ++ "." 
        		     ++ functionName ++ ": " ++ msg)
                
-----------------------------------------------------------
-- data definitions
-- PrimQuery is the data type of relational expressions. 
-- Since 'Project' takes an association, it is actually a
-- projection- and rename-operator at once.
-----------------------------------------------------------

type TableName  = String
type Attribute  = String
type Scheme     = [Attribute]
type Assoc      = [(Attribute,PrimExpr)]

data PrimQuery  = BaseTable TableName Scheme
                | Project   Assoc PrimQuery
                | Restrict  PrimExpr PrimQuery
                | Binary    RelOp PrimQuery PrimQuery
                | Special   SpecialOp PrimQuery
                | Empty
                
data RelOp      = Times 
                | Union 
                | Intersect 
                | Divide 
                | Difference
                deriving (Show)
                
data SpecialOp  = Order [PrimExpr]	--always UnExpr (OpDesc|OpAsc) (AttrExpr name) 
		| Top Bool Integer	--True = top percent, False = top n
				
data PrimExpr   = AttrExpr  Attribute
                | BinExpr   BinOp PrimExpr PrimExpr
                | UnExpr    UnOp PrimExpr
                | AggrExpr  AggrOp PrimExpr
                | ConstExpr String
                deriving (Read,Show)


data BinOp      = OpEq | OpLt | OpLtEq | OpGt | OpGtEq | OpNotEq 
                | OpAnd | OpOr
                | OpLike | OpIn 
                | OpOther String
                
                | OpCat
                | OpPlus | OpMinus | OpMul | OpDiv | OpMod
                | OpBitNot | OpBitAnd | OpBitOr | OpBitXor
                | OpAsg
                deriving (Show,Read)

data UnOp	= OpNot 
		| OpAsc | OpDesc
		| OpIsNull | OpIsNotNull
		deriving (Show,Read)

data AggrOp     = AggrCount | AggrSum | AggrAvg | AggrMin | AggrMax
                | AggrStdDev | AggrStdDevP | AggrVar | AggrVarP
                | AggrOther String
                deriving (Show,Read)

-----------------------------------------------------------
-- extend: creates a projection of some attributes while
--	   keeping all other attributes in the relation visible too. 
-- times : takes the cartesian product of two queries. .
-----------------------------------------------------------
extend :: Assoc -> PrimQuery -> PrimQuery
extend assoc query	
	= Project (assoc ++ assoc') query
        where
          assoc'  = assocFromScheme (attributes query)

times :: PrimQuery -> PrimQuery -> PrimQuery
times (Empty) query	= query
times query (Empty)     = query
times query1 query2     = assert "PrimQuery" "times" "overlapping attributes"
                                 (length (attributes query1 \\ attributes query2) == length (attributes query1))
                          Binary Times query1 query2

-----------------------------------------------------------
-- attributes	: returns the schema (the attributes) of a query
-- assocFromScheme: returns a one-to-one association of a
--	schema. ie. "assocFromScheme ["name","city"] becomes:
--	"[("name",AttrExpr "name"), ("city",AttrExpr "city")]"
-- attrInExpr	: returns all attributes in a qexpr 
-----------------------------------------------------------
attributes :: PrimQuery -> Scheme

attributes (Empty)              = []                            
attributes (BaseTable nm attrs) = attrs
attributes (Project assoc q)    = map fst assoc
attributes (Restrict expr q)    = attributes q
attributes (Special op q)	= attributes q
attributes (Binary op q1 q2)    = case op of
                                    Times       -> attr1 ++ attr2
                                    Union       -> attr1
                                    Intersect   -> attr1 \\ attr2
                                    Divide      -> attr1 
                                    Difference  -> attr1
                                where
                                  attr1         = attributes q1
                                  attr2         = attributes q2
                                                                   
assocFromScheme :: Scheme -> Assoc
assocFromScheme scheme          
		= map (\attr -> (attr,AttrExpr attr)) scheme


attrInExpr :: PrimExpr -> Scheme
attrInExpr      = foldPrimExpr (attr,scalar,binary,unary,aggr)
                where
                  attr name     = [name]
                  scalar s      = []
                  binary op x y = x ++ y
                  unary op x    = x
                  aggr op x	= x
                  

attrInOrder :: [PrimExpr] -> Scheme
attrInOrder  = concat . map attrInExpr
                  
-----------------------------------------------------------
-- Substitute attributes names in an expression.
-----------------------------------------------------------
substAttr :: Assoc -> PrimExpr -> PrimExpr                  
substAttr assoc 
        = foldPrimExpr (attr,ConstExpr,BinExpr,UnExpr,AggrExpr)
        where        
          attr name     = case (lookup name assoc) of        
                            Just x      -> x        
                            Nothing     -> AttrExpr name                          
                  
  
isAggregate, nestedAggregate :: PrimExpr -> Bool
isAggregate x		= countAggregate x > 0
nestedAggregate x	= countAggregate x > 1
	                
countAggregate :: PrimExpr -> Int
countAggregate
	= foldPrimExpr (const 0, const 0, binary, unary, aggr)
	where
          binary op x y	 	= x + y
          unary op x		= x
          aggr op x		= x + 1
	                    
-----------------------------------------------------------
-- fold on PrimQuery's and PrimExpr's
-----------------------------------------------------------

foldPrimQuery (empty,table,project,restrict,binary,special) 
        = fold
        where
          fold (Empty)  = empty
          fold (BaseTable name schema)
                        = table name schema
          fold (Project assoc query)
                        = project assoc (fold query)
          fold (Restrict expr query)
                        = restrict expr (fold query)
          fold (Binary op query1 query2)
                        = binary op (fold query1) (fold query2)
          fold (Special op query)
          		= special op (fold query)
          fold _        = error "PrimQuery.foldPrimQuery: undefined case"
          
foldPrimExpr (attr,scalar,binary,unary,aggr) 
        = fold
        where
          fold (AttrExpr name)  = attr name
          fold (ConstExpr s)    = scalar s
          fold (BinExpr op x y) = binary op (fold x) (fold y)
          fold (UnExpr op x)    = unary op (fold x)
          fold (AggrExpr op x)	= aggr op (fold x)
          fold _                = error "PrimQuery.foldPrimExpr: undefined case"

-----------------------------------------------------------
-- Pretty print PrimQuery and PrimExpr.
-- coincidently, ppPrimExpr shows exactly a valid SQL expression :-)
-----------------------------------------------------------
instance Show PrimQuery where
  showsPrec d qt        = shows (pretty qt)
  
instance Pretty PrimQuery where
  pretty                = ppPrimQuery

ppPrimQuery = foldPrimQuery (empty,table,project,restrict,binary,special)
        where
          ontop d e             = tab (d $$ e)
          
          empty                 = emptyDoc
          table name scheme     = htext ["BaseTable",name] <+> ppScheme scheme
          project assoc         = ontop $ text "Project" <+> ppAssoc assoc
          restrict x            = ontop $ text "Restrict" <+> ppPrimExpr x
          binary op d1 d2       = tab (ppRelOp op $$ (d1 $$ d2))
          special op 		= ontop $ ppSpecialOp op
          
          
ppScheme                        = braces . commas . map text          
ppAssoc                         = braces . commas . map ppNameExpr
ppNameExpr (attr,expr)          = text attr <> colon <+> ppPrimExpr expr
          
          
instance Pretty PrimExpr where
  pretty = ppPrimExpr  

ppPrimExpr = foldPrimExpr (attr,scalar,binary,unary,aggr)
        where
          attr          = text
          scalar        = text . unquote 
          binary op x y = parens (x <+> ppBinOp  op </> y)
          
          unary OpAsc x = x <+> text "ASC"
          unary OpDesc x= x <+> text "DESC" 
          unary op x    = parens (ppUnOp  op <+> x)
          
          aggr op x	= ppAggrOp op <> parens x
          
          -- be careful when showing a SQL string
          unquote ('"':s)       = "'" ++ (concat (map tosquote (init s))) ++ "'"
          unquote s             = s
          
          tosquote '\''         = "\\'"
          tosquote c            = [c]
          
          
ppRelOp  op		= text (showRelOp  op) 
ppUnOp	 op		= text (showUnOp   op)         
ppBinOp  op             = text (showBinOp  op)
ppAggrOp op             = text (showAggrOp op)


ppSpecialOp (Order xs)  = commas (map ppPrimExpr xs)		          
ppSpecialOp (Top perc n)= text "TOP" <+> text (show n) <+>
			  (if perc then text "PERCENT" else emptyDoc)
			  
-----------------------------------------------------------
-- Show expression operators, coincidently they show
-- exactly the SQL equivalents 
-----------------------------------------------------------

showRelOp Times		= "TIMES"
showRelOp Union        	= "UNION"
showRelOp Intersect    	= "INTERSECT"
showRelOp Divide       	= "DIVIDE"
showRelOp Difference   	= "MINUS"

showUnOp  OpNot         = "NOT" 
showUnOp  OpIsNull      = "IS NULL" 
showUnOp  OpIsNotNull   = "IS NOT NULL" 
--showUnOp  OpAsc
--showUnOp  OpDesc  

showBinOp  OpEq         = "=" 
showBinOp  OpLt         = "<" 
showBinOp  OpLtEq       = "<=" 
showBinOp  OpGt         = ">" 
showBinOp  OpGtEq       = ">=" 
showBinOp  OpNotEq      = "<>" 
showBinOp  OpAnd        = "AND"  
showBinOp  OpOr         = "OR" 
showBinOp  OpLike       = "LIKE" 
showBinOp  OpIn         = "IN" 
showBinOp  (OpOther s)  = s
                
showBinOp  OpCat        = "+" 
showBinOp  OpPlus       = "+" 
showBinOp  OpMinus      = "-" 
showBinOp  OpMul        = "*" 
showBinOp  OpDiv        = "/" 
showBinOp  OpMod        = "MOD" 
showBinOp  OpBitNot     = "~" 
showBinOp  OpBitAnd     = "&" 
showBinOp  OpBitOr      = "|" 
showBinOp  OpBitXor     = "^"
showBinOp  OpAsg        = "="

showAggrOp AggrCount    = "COUNT" 
showAggrOp AggrSum      = "SUM" 
showAggrOp AggrAvg      = "AVG" 
showAggrOp AggrMin      = "MIN" 
showAggrOp AggrMax      = "MAX" 
showAggrOp AggrStdDev   = "StdDev" 
showAggrOp AggrStdDevP  = "StdDevP" 
showAggrOp AggrVar      = "Var" 
showAggrOp AggrVarP     = "VarP"                
showAggrOp (AggrOther s)        = s