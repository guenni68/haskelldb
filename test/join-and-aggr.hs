import System (getArgs)
import Control.Monad (unless)

import HaskellDB
import Query (runQuery) -- for debugging
import HDBRec
import Dp037.D3proj_time_reports hiding (xid)
import qualified Dp037.D3proj_time_reports
import Dp037.D3proj_users
--import HSQL_PostgreSQL
import HSQL_ODBC

{-

Tables:

CREATE TABLE d3proj_time_reports (
  id int NOT NULL,
  username varchar(8) NOT NULL,
  day date NOT NULL,
  hours float NOT NULL,
  activity text NOT NULL,
  reported timestamp NOT NULL,
  PRIMARY KEY (id)
)

CREATE TABLE d3proj_users (
  id varchar(8) NOT NULL,
  first_name varchar(255) NOT NULL,
  last_name varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  PRIMARY KEY (id)
)

-}



opts = ODBCOptions{dsn="mysql-dp037", uid="dp037", pwd="teent333"}
withDB f = odbcConnect opts f

--opts = PostgreSQLOptions{server="localhost", db="dp037", uid="dp037", pwd="teent333"}
--withDB f = postgresqlConnect opts f

reports userid
    = do
      reports <- table d3proj_time_reports
      users <- table d3proj_users
      restrict (reports!username .==. users!xid .&&. reports!username .==. constant userid)
      project (first_name << users!first_name 
	       # last_name << users!last_name
	       # activity << reports!activity)

avgWorkChunks
    = do
      reports <- table d3proj_time_reports
      users <- table d3proj_users
      restrict (reports!username .==. users!xid)
      r <- project (first_name << users!first_name 
		    # last_name << users!last_name
		    # hours << avg (reports!hours))
      order [asc r hours]
      return r

floatTest 
    = do
      reports <- table d3proj_time_reports
      project (hours << reports!hours)

doFloatTest db
    = do 
      result <- query db floatTest
      mapM_ (putStrLn . (\r -> show (r!.hours))) result


actToString r = r!.first_name ++ " " ++ r!.last_name ++ ": " ++ r!.activity

printActivity username db 
    = do
      result <- query db (reports username)
--      fs <- describe db "d3proj_users"
--      putStrLn $ unlines $ map show fs
      mapM_ (putStrLn . actToString) result

printAvgWorkChunks db 
    = do
      result <- query db avgWorkChunks 
      mapM_ (putStrLn . showRow) result
      where showRow r = r!.first_name ++ " " ++ r!.last_name ++ ": " ++ show (r!.hours) ++ " h"

main = do
--       args <- getArgs
--       unless (length args == 1) (fail "Usage: test <username>")
--       let (username:_) = args
--       putStrLn $ show $ q username
--       withDB (printActivity username)
       putStrLn $ show $ runQuery avgWorkChunks
       putStrLn $ show $ showQ avgWorkChunks
       putStrLn $ show $ showOpt avgWorkChunks
       putStrLn $ show $ showOpt floatTest
       withDB printAvgWorkChunks
--       withDB doFloatTest
