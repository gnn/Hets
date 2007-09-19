{- |
Module      :  $Id$
Description :  Abstract syntax fo CspCASL
Copyright   :  (c) Markus Roggenbach and Till Mossakowski and Uni Bremen 2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  a.m.gimblett@swan.ac.uk
Stability   :  provisional
Portability :  portable

Abstract syntax of CSP-CASL processes.

-}
module CspCASL.AS_CspCASL where

import CASL.AS_Basic_CASL (BASIC_SPEC)
--import Common.Doc
--import Common.DocUtils
import Common.Id (Id)

import CspCASL.AS_CspCASL_Process (PROCESS)

type CCSPEC_NAME = Id

data BASIC_CSP_CASL_SPEC
    = Basic_Csp_Casl_Spec CCSPEC_NAME DATA_DEFN PROCESS
    deriving (Show)

--instance Pretty BASIC_CSP_CASL_SPEC where
--    pretty _ = text ""


{- First line only of:
  DATA-DEFN ::=   SPEC
                 | SPEC-DEFN
                 | LIB-IMPORT ... LIB-IMPORT SPEC
                 | LIB-IMPORT ... LIB-IMPORT SPEC-DEFN 
-}
data DATA_DEFN
    = Spec (BASIC_SPEC () () ())
    deriving (Show)
