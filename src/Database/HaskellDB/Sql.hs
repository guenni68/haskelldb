-----------------------------------------------------------
-- Daan Leijen (c) 1999, daan@cs.uu.nl
--
-- module SQL:
-- Transform a PrimQuery (relational expression) to SQL
-- and pretty print SQL
-----------------------------------------------------------
module Sql ( SqlSelect(..) 
	   , SqlUpdate(..) 
	   , SqlDelete(..) 
	   , SqlInsert(..)
	   
	   , toSql, ppSql
	   , toUpdate, ppUpdate
	   , toDelete, ppDelete
	   , toInsert, ppInsert
	   , toInsertNew
	   ) where

import List (intersect)
import PPrint
import PrimQuery

-----------------------------------------------------------
-- SQL data type
-----------------------------------------------------------

data SqlSelect  = SqlSelect   { options  :: [String]
			      , attrs    :: [(Attribute,String)]
                              , tables   :: [(TableName,SqlSelect)]
                              , criteria :: [String]
                              , groupby  :: [String]
                              , orderby	 :: [PrimExpr]
                              }
                | SqlBin   String SqlSelect SqlSelect
                | SqlTable TableName
                | SqlEmpty


data SqlUpdate  = SqlUpdate TableName [String] [String]

data SqlDelete  = SqlDelete TableName [String]

data SqlInsert  = SqlInsertNew  TableName [(Attribute,String)]
                | SqlInsert TableName SqlSelect



newSelect       = SqlSelect { options   = []
			    , attrs 	= []
			    , tables 	= []
			    , criteria 	= []
			    , groupby	= []
			    , orderby	= [] }


-----------------------------------------------------------
-- SELECT
-- Hmm, bit messy.
-----------------------------------------------------------

-- invariant: null attrs => null groupby

toSql   :: PrimQuery -> SqlSelect
toSql   = foldPrimQuery (empty,table,project,restrict,binary,special)
        where
          empty             	= SqlEmpty
          table name schema 	= SqlTable name
	 
          project assoc q
          	| hasAggr    = select { groupby = map toSqlExpr nonAggrs }
          	| otherwise  = select 
                where
                  select   = sql { attrs = toSqlAssoc assoc }
                  sql      = toSelect q

                  hasAggr  = any isAggregate exprs
                  
                  -- TODO: we should make sure that every non-aggregate 
                  -- is only a simple attribute expression
                  nonAggrs = filter (not.isAggregate) exprs
                  
                  exprs    = map snd assoc
		  
          restrict expr q
                = sql { criteria = toSqlExpr expr : criteria sql }
                where
                  sql   = toSelect q
                  
          -- binary assumes that q1 and q2 are not empty
          binary Times q1 q2  
          	| null (attrs q1) = addTable q1 q2
          	| null (attrs q2) = addTable q2 q1
          	| otherwise       = newSelect { tables = [("",q1),("",q2)] }
          	where
          	  addTable sql q  = sql{ tables = tables sql ++ [("",q)] }
		 
          binary op q1 q2         
          	= SqlBin (toSqlOp op) q1 q2


	  special (Order newOrder) q
	  	= sql { orderby = newOrder ++ oldOrder }  
		where
		  sql 	    = toSelect q
		  
		  oldOrder  = filter notdup (orderby sql)
		  notdup x  = null (attrInExpr x `intersect` attrInOrder newOrder)
		  
		  	    
		  	    
          special op q
          	= sql { options = show (ppSpecialOp op) : options sql }
          	where
                  sql	    = toSelect q

toSelect sql    = case sql of
                    (SqlEmpty)          -> newSelect
                    (SqlTable name)     -> newSelect { tables = [("",sql)] }
                    (SqlBin op q1 q2)   -> newSelect { tables = [("",sql)] }
                    (SqlSelect {attrs}) | null attrs -> sql
                                        | otherwise  -> newSelect { tables = [("",sql)] }

toSqlAssoc      = map (\(attr,expr) -> (attr, toSqlExpr expr))
toSqlExpr       = show . ppPrimExpr

toSqlOp Union        = "UNION"
toSqlOp Intersect    = "INTERSECT"
toSqlOp Divide       = "DIVIDE"
toSqlOp Difference   = "MINUS"


-----------------------------------------------------------
-- SELECT, show & pretty print
-----------------------------------------------------------

instance Pretty SqlSelect where
  pretty        = ppSql

ppSql (SqlSelect { options, attrs, tables, criteria, groupby, orderby })
        = indent $
          text "SELECT DISTINCT" <+> htext options <+> ppAttrs attrs
       $$ f "FROM " ppTables tables
       $$ f "WHERE" ppCriteria criteria
       $$ f "GROUP BY" ppGroupBy groupby
       $$ f "ORDER BY" ppOrderBy orderby
        where
          f clause action xs    | null xs       = emptyDoc
                                | otherwise     = text clause <+> action xs

ppSql (SqlBin op sql1 sql2)     = ppSql sql1 $$ text op $$ ppSql sql2
ppSql (SqlTable name)           = text name
ppSql (SqlEmpty)                = text ""


-- helpers

ppAttrs []	= text "*"                                                   		
ppAttrs xs      = commas (map nameAs xs)                               		
                                                                 
ppCriteria      = sepby (text " AND ") . map text                      		
ppTables        = commas . map ppTable . zipWith tableAlias [1..]      		
ppGroupBy	= commas . map text 		
ppOrderBy ord	= ppSpecialOp (Order ord)

tableAlias i (_,sql)  		= ("T" ++ show i,sql)

ppTable (alias,(SqlTable name)) = ppAs alias (text name)
ppTable (alias,sql)             = ppAs alias (parens (ppSql sql))


nameAs (name,expr)	| name == expr  = text name                                
                        | otherwise     = ppAs name (text expr)              
                                                                     
ppAs alias expr         | null alias    = expr                               
                        | otherwise     = expr <+> htext ["as",alias]        


-----------------------------------------------------------
-- INSERT
-----------------------------------------------------------
toInsert :: TableName -> PrimQuery -> SqlInsert
toInsert table qtree
	= SqlInsert table (toSql qtree)

toInsertNew :: TableName -> Assoc -> SqlInsert
toInsertNew table assoc
	= SqlInsertNew table (map showExpr assoc)
	where
	  showExpr (attr,expr)	= (attr,show (pretty expr))

-- pretty
ppInsert (SqlInsert table select)
	= text "INSERT INTO" <+> text table
        $$ indent (ppSql select)


ppInsert (SqlInsertNew table exprs)
	= text "INSERT INTO" <+> text table <+> parens (commas (map text names))
        $$ text "VALUES"     <+> parens (commas (map text values))
        where
          (names,values)        = unzip exprs


-----------------------------------------------------------
-- DELETE
-----------------------------------------------------------

toDelete :: TableName -> [PrimExpr] -> SqlDelete
toDelete name exprs
        = SqlDelete name (map toSqlExpr exprs)

ppDelete (SqlDelete name exprs)
        | null exprs    =  text ""
        | otherwise     =  text "DELETE FROM" <+> text name
                        $$ text "WHERE" <+> ppCriteria exprs

-----------------------------------------------------------
-- UPDATE
-----------------------------------------------------------

toUpdate :: TableName -> [PrimExpr] -> Assoc -> SqlUpdate
toUpdate name criteria assigns
        = SqlUpdate name (map toSqlExpr criteria)
        		 (map showAssign assigns)
        where
          showAssign (attr,expr)
          	= attr ++ " = " ++ toSqlExpr expr

ppUpdate (SqlUpdate name criteria assigns)
        = text "UPDATE" <+> text name
        $$ text "SET" <+> commas (map text assigns)
        $$ f "WHERE" ppCriteria criteria
        where
           f clause action xs   | null xs    = emptyDoc
                                | otherwise  = text clause <+> action xs