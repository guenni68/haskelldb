{-# OPTIONS_GHC -fcontext-stack44 #-}
-- NOTE: use GHC flag -fcontext-stack44 with this module if GHC < 6.8.1
---------------------------------------------------------------------------
-- Generated by DB/Direct
---------------------------------------------------------------------------
module DB1.Bool_tbl where

import Database.HaskellDB.DBLayout

---------------------------------------------------------------------------
-- Table type
---------------------------------------------------------------------------

type Bool_tbl =
    Record (HCons (LVPair F01 (Expr (Maybe Bool)))
            (HCons (LVPair F02 (Expr Bool))
             (HCons (LVPair F03 (Expr (Maybe Bool)))
              (HCons (LVPair F04 (Expr Bool)) HNil))))

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
bool_tbl :: Table Bool_tbl
bool_tbl = baseTable "bool_tbl"

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
