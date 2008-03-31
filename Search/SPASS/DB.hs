{- |
Module      :  $Header$
Description :  Main module to read dfg files into the database
Copyright   :  (c) Immanuel Normann, Uni Bremen 2007
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  inormann@jacobs-university.de
Stability   :  provisional
Portability :  portable
-}
module Main where

import Data.List as L
import Search.Common.Normalization
import Search.Common.Select (search,LongInclusionTuple) 
import SoftFOL.Sign
import Search.SPASS.FormulaWrapper
import Search.SPASS.UnWrap --hiding (formula)
import System.Directory
import System.IO
import Text.ParserCombinators.Parsec
import MD5
import Search.DB.Connection
import System.Environment (getArgs)


main = do args <- getArgs
          case args of
            ("search":dir:file:_) -> searchDFG dir file >> return ()
            ("insert":lib:dir:file:_) -> indexFile lib dir file  >> return ()
            _ -> error "invalid arguments!\nShould be <library> <dir> <file>"

-- -----------------------------------------------------------
-- * Search
-- -----------------------------------------------------------

{- |
   searchDFG reads in a source theory from file and returns all possible profile morphisms
   from all matching target theories in the database.
-}
searchDFG :: FilePath -> TheoryName
              -> IO [[LongInclusionTuple SPIdentifier]]
searchDFG = search readAxiomsAndTheorems

{- |
   readProblem reads in from file a dfg problem and returns
   all axioms but removes duplicates and trivially true axioms.
-}
--readAxiomsAndTheorems :: FilePath -> FilePath -> IO ([Profile],[DFGProfile])
readAxiomsAndTheorems dir file =
    do fs <- readDFGFormulae (dir ++ "/" ++ file)
       return $ cleanUp fs

--cleanUp :: DFGProfile -> ([ShortProfile String],[ShortProfile String])
cleanUp fs = (axioms,theorems)
    where fs1 = nubBy eqSen $ filter isNotTrueAtom $ map (dfgNormalize ("","")) fs
          isAxiom p = role p == Axiom
          (ax,th) = partition isAxiom fs1
          toSProfile p = (md5s $ Str $ show $ skeleton p, parameter p, lineNr p, show $ role p)
          (axioms,theorems) = (map toSProfile ax, map toSProfile th)

-- -----------------------------------------------------------
-- * Indexing
-- -----------------------------------------------------------


{-|
  indexFile reads the file TheoryName in directory FilePath and feeds it
  to the database. The first argument specifies the library the theory
  should be associated with.
-}

indexFile lib dir file =
    do fs <- readDFGFormulae (dir ++ "/" ++ file)
       (nrOfTautologies,nrOfDuplicates,fs3,len) <- return $ normalizeAndAnalyze fs
       multiInsertProfiles (map toPTuple fs3)
       insertStatistics (lib,file,nrOfTautologies,nrOfDuplicates,len)
       return (file,nrOfTautologies,nrOfDuplicates,len)


{-|
  indexDir reads all files from the directory FilePath and feeds them
  to the database. The first argument specifies the library the theories
  should be associated with.
-}
indexDir :: String -> FilePath -> IO [(TheoryName, Int, Int, Int)]
indexDir lib dir =
    let showRec (file,ts,ds,fs) = file ++ "\t" ++ (show ts) ++ "\t" ++ 
                                  (show ds) ++ "\t" ++ (show fs)
    in do ls <- getDirectoryContents dir
          setCurrentDirectory dir
          rec <- mapM (indexFile lib dir) (L.filter (L.isSuffixOf "dfg") ls)
          putStrLn (concatMap showRec rec)
          return rec

-- -----------------------------------------------------------
-- * Helper Functions
-- -----------------------------------------------------------

eqSen f1 f2 = (skeleton f1) == (skeleton f2) &&
              (parameter f1) == (parameter f2) &&
              (role f1) == (role f2)

isNotTrueAtom f = case skeleton f
                  of (Const TrueAtom []) -> False
                     _ -> True

normalizeAndAnalyze fs = (nrOfTautologies,nrOfDuplicates,fs3,length fs3)
    where fs1 = map (dfgNormalize ("","")) fs
          fs2 = filter isNotTrueAtom fs1
          nrOfTautologies = (length fs1) - (length fs2)
          fs3 = nubBy eqSen fs2
          nrOfDuplicates = (length fs2) - (length fs3)

toPTuple p = (library',file',line',role',formula',skeleton',parameter',strength')
    where library' = libName p
          file' = theoryName p
          line' = lineNr p
          formula' = show $ formula p
          skeleton' = show $ skeleton p
          parameter' = show $ parameter p
          role' = show $ role p
          strength' = strength p

