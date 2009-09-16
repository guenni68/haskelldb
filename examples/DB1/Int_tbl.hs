{-# OPTIONS_GHC -fcontext-stack44 #-}
-- NOTE: use GHC flag -fcontext-stack44 with this module if GHC < 6.8.1
---------------------------------------------------------------------------
-- Generated by DB/Direct
---------------------------------------------------------------------------
module DB1.Int_tbl where

import Database.HaskellDB.DBLayout
import Database.HaskellDB

---------------------------------------------------------------------------
-- Table type
---------------------------------------------------------------------------

type Int_tbl =
    Record (HCons (LVPair F01 (Expr (Maybe Int)))
            (HCons (LVPair F02 (Expr Int))
             (HCons (LVPair F03 (Expr (Maybe Int)))
              (HCons (LVPair F04 (Expr Int)) HNil))))

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
int_tbl :: Table Int_tbl
int_tbl = baseTable "int_tbl"

---------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- F01 Field
---------------------------------------------------------------------------

data F01Tag
type F01 = Proxy F01Tag
instance ShowLabel F01 where showLabel _ = "f01"

f01 :: F01
f01 = proxy

---------------------------------------------------------------------------
-- F02 Field
---------------------------------------------------------------------------

data F02Tag
type F02 = Proxy F02Tag
instance ShowLabel F02 where showLabel _ = "f02"

f02 :: F02
f02 = proxy

---------------------------------------------------------------------------
-- F03 Field
---------------------------------------------------------------------------

data F03Tag
type F03 = Proxy F03Tag
instance ShowLabel F03 where showLabel _ = "f03"

f03 :: F03
f03 = proxy

---------------------------------------------------------------------------
-- F04 Field
---------------------------------------------------------------------------

data F04Tag
type F04 = Proxy F04Tag
instance ShowLabel F04 where showLabel _ = "f04"

f04 :: F04
f04 = proxy

---------------------------------------------------------------------------
-- Table type
---------------------------------------------------------------------------

type T1 =
    Record (HCons (LVPair F1 (Expr (Maybe Int)))
            (HCons (LVPair F2 (Expr (Maybe Int))) HNil))

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
t1 :: Table T1
t1 = baseTable "t1"

---------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- F1 Field
---------------------------------------------------------------------------

data F1Tag
type F1 = Proxy F1Tag
instance ShowLabel F1 where
    showLabel _ = "f1"

f1 :: F1
f1 = proxy

---------------------------------------------------------------------------
-- F2 Field
---------------------------------------------------------------------------

data F2Tag
type F2 = Proxy F2Tag
instance ShowLabel F2 where showLabel _ = "f2"

f2 :: F2
f2 = proxy

