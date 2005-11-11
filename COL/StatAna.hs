{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder, Uni Bremen 2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  till@tzi.de
Stability   :  provisional
Portability :  portable

static analysis of COL parts
-}

module COL.StatAna where

import COL.AS_COL
import COL.COLSign

import CASL.StaticAna

import Common.AS_Annotation
import qualified Common.Lib.Set as Set
import qualified Common.Lib.Map as Map
import Common.Id
import Common.Result

addConstructor :: Id -> COLSign -> Result COLSign
addConstructor i m = return
       m { constructors = Set.insert i $ constructors m }

addObserver :: (Id, Maybe Int) -> COLSign -> Result COLSign
addObserver (i, v) m = return
       m { observers = Map.insert i (maybe 0 id v) $ observers m }

ana_COL_SIG_ITEM :: Ana COL_SIG_ITEM () COL_SIG_ITEM () COLSign
ana_COL_SIG_ITEM _ mi =
    case mi of
    Constructor_items al ps -> do
        mapM_ (updateExtInfo . addConstructor . item) al
        return $ Constructor_items al ps
    Observer_items al ps -> do
        mapM_ (updateExtInfo . addObserver . item) al
        return $ Observer_items al ps
