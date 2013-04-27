{- |
Module      :  $Header$
Description :  Import data generated by hol2hets into a DG
Copyright   :  (c) Jonathan von Schroeder, DFKI GmbH 2010
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  jonathan.von_schroeder@dfki.de
Stability   :  experimental
Portability :  portable

-}

module Isabelle.Isa2DG where

import Static.GTheory
import Static.DevGraph

import Static.DgUtils
import Static.History
import Static.ComputeTheory
import Static.AnalysisStructured (insLink)

import Logic.Prover
import Logic.ExtSign
import Logic.Grothendieck
import Logic.Logic (ide)

import Common.LibName
import Common.Id
import Common.AS_Annotation
import Common.IRI (simpleIdToIRI)

import Isabelle.Logic_Isabelle
import Isabelle.IsaSign
import Isabelle.IsaConsts (mkVName)
import Isabelle.IsaImport (importIsaDataIO)

import Driver.Options

import qualified Data.Map as Map
import Data.Graph.Inductive.Graph (Node)

import Control.Monad (unless)
import Control.Concurrent (forkIO,killThread)

import Common.Utils
import System.Exit
import System.Directory
import System.FilePath

makeNamedSentence :: (String, Term) -> Named Sentence
makeNamedSentence (n, t) = makeNamed n $ mkSen t

_insNodeDG :: Sign -> [Named Sentence] -> String
              -> DGraph -> (DGraph,Node)
_insNodeDG sig sens n dg =
 let gt = G_theory Isabelle Nothing (makeExtSign Isabelle sig) startSigId
           (toThSens sens) startThId
     labelK = newInfoNodeLab
      (makeName (simpleIdToIRI (mkSimpleId n)))
      (newNodeInfo DGEmpty)
      gt
     k = getNewNodeDG dg
     insN = [InsertNode (k, labelK)]
     newDG = changesDGH dg insN
     labCh = [SetNodeLab labelK (k, labelK
      { globalTheory = computeLabelTheory Map.empty newDG
        (k, labelK) })]
     newDG1 = changesDGH newDG labCh in (newDG1,k)

analyzeMessages :: Int -> [String] -> IO ()
analyzeMessages _ []     = return ()
analyzeMessages i (x:xs) = do
 case x of
  'v':i':':':msg -> if (read [i']) < i then putStr $ msg ++ "\n"
                                 else return ()
  _ -> putStr $ x ++ "\n"
 analyzeMessages i xs

anaThyFile :: HetcatsOpts -> FilePath -> IO (Maybe (LibName, LibEnv))
anaThyFile opts path = do
 fp <- canonicalizePath path
 tempFile <- getTempFile "" (takeBaseName fp)
 fifo <- getTempFifo (takeBaseName fp)
 exportScript' <- fmap (</> "export.sh") $ getEnvDef
  "HETS_ISA_TOOLS" "./Isabelle/export"
 exportScript <- canonicalizePath exportScript'
 e1 <- doesFileExist exportScript
 unless e1 $ fail $ "Export script not available! Maybe you need to specify HETS_ISA_TOOLS"
 (l,close) <- readFifo fifo
 tid <- forkIO $ analyzeMessages (verbose opts) (lines . concat $ l)
 (ex, sout, err) <- executeProcess exportScript [fp,tempFile,fifo] ""
 close
 killThread tid
 removeFile fifo
 case ex of
  ExitFailure _ -> do
   removeFile tempFile
   soutF <- getTempFile sout ((takeBaseName fp) ++ ".sout")
   errF <- getTempFile err ((takeBaseName fp) ++ ".serr")
   fail $ "Export Failed! - Export script died prematurely. See " ++ soutF
          ++ " and " ++ errF ++ " for details."
  ExitSuccess -> do
   ret <- anaIsaFile opts tempFile
   removeFile tempFile
   return ret

mkNode :: (String,[String],[(String,Typ)],
     [(String,Term)], [(String,Term)],
     DomainTab, [(String,FunDef)],
     [(IsaClass,ClassDecl)],
     [(String,LocaleDecl)]) -> (DGraph,Map.Map String (Node,Sign)) ->
     (DGraph,Map.Map String (Node,Sign))
mkNode (name,imps,consts,axioms,theorems,types,funs',classes,locales') (dg,m) =
 let sens = map makeNamedSentence $ axioms ++ theorems
     sgn' = emptySign { constTab = foldl (\ m_ (n',t) -> Map.insert (mkVName n')
                                          t m_) Map.empty consts,
                       domainTab = types, imports = imps, baseSig = Custom_thy,
                       tsig = emptyTypeSig { classrel = Map.fromList classes,
                                             locales  = Map.fromList locales',
                                             funs     = Map.fromList funs' }}
     sgns = Map.foldWithKey (\k a l ->
             if elem k imps then (snd a):l else l) [] m
     sgn  = foldl union_sig sgn' sgns
     (dg',n) = _insNodeDG sgn sens name dg
     m'      = Map.insert name (n,sgn) m
     dgRet   = foldr (\imp dg'' ->
                         case Map.lookup imp m of
                          Just (n',s') -> 
                           let gsig = G_sign Isabelle (makeExtSign Isabelle s')
                                       startSigId
                               incl = gEmbed2 gsig $ mkG_morphism Isabelle
                                       (ide sgn)
                           in insLink dg'' incl globalDef DGLinkImports n' n
                          Nothing -> dg'') dg' imps
 in (dgRet,m')

anaIsaFile :: HetcatsOpts -> FilePath -> IO (Maybe (LibName, LibEnv))
anaIsaFile _ path = do
 theories <- importIsaDataIO path
 let name   = "Imported Theory"
     (dg,_) = foldr mkNode (emptyDG,Map.empty) theories
     le     = Map.insert (emptyLibName name) dg Map.empty
 return $ Just (emptyLibName name,
  computeLibEnvTheories le)
