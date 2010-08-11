{- |
Module      :  $EmptyHeader$
Description :  <optional short description entry>
Copyright   :  (c) <Authors or Affiliations>
License     :  GPLv2 or higher

Maintainer  :  <email>
Stability   :  unstable | experimental | provisional | stable | frozen
Portability :  portable | non-portable (<reason>)

<optional description>
-}
-- NOTE: use GHC flag -fcontext-stack50 with this module
---------------------------------------------------------------------------
-- Generated by DB/Direct
---------------------------------------------------------------------------
module Search.DB.FormulaDB.Profile where

import Database.HaskellDB.DBLayout

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
profile :: Table
    ((RecCons Library (Expr String)
      (RecCons File (Expr String)
       (RecCons Line (Expr Int)
        (RecCons Formula (Expr String)
         (RecCons Skeleton (Expr String)
          (RecCons Skeleton_md5 (Expr String)
           (RecCons Parameter (Expr String)
            (RecCons Role (Expr String)
             (RecCons Norm_strength (Expr String)
              (RecCons Skeleton_length (Expr Int) RecNil)))))))))))

profile = baseTable "profile" $
          hdbMakeEntry Library #
          hdbMakeEntry File #
          hdbMakeEntry Line #
          hdbMakeEntry Formula #
          hdbMakeEntry Skeleton #
          hdbMakeEntry Skeleton_md5 #
          hdbMakeEntry Parameter #
          hdbMakeEntry Role #
          hdbMakeEntry Norm_strength #
          hdbMakeEntry Skeleton_length

---------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Library Field
---------------------------------------------------------------------------

data Library = Library

instance FieldTag Library where fieldName _ = "library"

library :: Attr Library String
library = mkAttr Library

---------------------------------------------------------------------------
-- File Field
---------------------------------------------------------------------------

data File = File

instance FieldTag File where fieldName _ = "file"

file :: Attr File String
file = mkAttr File

---------------------------------------------------------------------------
-- Line Field
---------------------------------------------------------------------------

data Line = Line

instance FieldTag Line where fieldName _ = "line"

line :: Attr Line Int
line = mkAttr Line

---------------------------------------------------------------------------
-- Formula Field
---------------------------------------------------------------------------

data Formula = Formula

instance FieldTag Formula where fieldName _ = "formula"

formula :: Attr Formula String
formula = mkAttr Formula

---------------------------------------------------------------------------
-- Skeleton Field
---------------------------------------------------------------------------

data Skeleton = Skeleton

instance FieldTag Skeleton where fieldName _ = "skeleton"

skeleton :: Attr Skeleton String
skeleton = mkAttr Skeleton

---------------------------------------------------------------------------
-- Skeleton_md5 Field
---------------------------------------------------------------------------

data Skeleton_md5 = Skeleton_md5

instance FieldTag Skeleton_md5 where fieldName _ = "skeleton_md5"

skeleton_md5 :: Attr Skeleton_md5 String
skeleton_md5 = mkAttr Skeleton_md5

---------------------------------------------------------------------------
-- Parameter Field
---------------------------------------------------------------------------

data Parameter = Parameter

instance FieldTag Parameter where fieldName _ = "parameter"

parameter :: Attr Parameter String
parameter = mkAttr Parameter

---------------------------------------------------------------------------
-- Role Field
---------------------------------------------------------------------------

data Role = Role

instance FieldTag Role where fieldName _ = "role"

role :: Attr Role String
role = mkAttr Role

---------------------------------------------------------------------------
-- Norm_strength Field
---------------------------------------------------------------------------

data Norm_strength = Norm_strength

instance FieldTag Norm_strength where
    fieldName _ = "norm_strength"

norm_strength :: Attr Norm_strength String
norm_strength = mkAttr Norm_strength

---------------------------------------------------------------------------
-- Skeleton_length Field
---------------------------------------------------------------------------

data Skeleton_length = Skeleton_length

instance FieldTag Skeleton_length where
    fieldName _ = "skeleton_length"

skeleton_length :: Attr Skeleton_length Int
skeleton_length = mkAttr Skeleton_length
