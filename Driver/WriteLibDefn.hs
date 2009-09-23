{- |
Module      :  $Header$
Description :  Writing out a HetCASL library
Copyright   :  (c) Klaus Luettich, C.Maeder, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(DevGraph)

Writing out HetCASL env files as much as is needed for
the static analysis
-}

module Driver.WriteLibDefn
  ( getFilePrefix
  , writeLibDefn
  , writeLibDefnLatex
  , toShATermString
  , writeShATermFile
  , writeFileInfo
  ) where

import Common.Utils
import Common.Doc
import Common.DocUtils
import Common.LibName
import Common.PrintLaTeX
import Common.GlobalAnnotations (GlobalAnnos)
import Common.ConvertGlobalAnnos ()

import ATerm.AbstractSyntax
import qualified ATerm.ReadWrite as AT

import ATC.AS_Library ()
import ATC.DevGraph ()
import ATC.Grothendieck

import Syntax.AS_Library (LIB_DEFN())
import Syntax.Print_AS_Library ()
import Syntax.ToXml

import Text.XML.Light (ppTopElement)

import Driver.Options

import System.FilePath

-- | compute the prefix for files to be written out
getFilePrefix :: HetcatsOpts -> FilePath -> (FilePath, FilePath)
getFilePrefix opts file =
    let odir' = outdir opts
        (base, path, _) = fileparse (envSuffix : downloadExtensions) file
        odir = if null odir' then path else odir'
    in (odir, odir </> base)

{- |
  Write the given LIB_DEFN in every format that HetcatsOpts includes.
  Filenames are determined by the output formats.
-}
writeLibDefn :: GlobalAnnos -> FilePath -> HetcatsOpts -> LIB_DEFN -> IO ()
writeLibDefn ga file opts ld = do
    let (odir, filePrefix) = getFilePrefix opts file
        printXml fn = writeFile fn $ ppTopElement (xmlLibDefn ga ld) ++ "\n"
        printAscii fn = writeFile fn $ showGlobalDoc ga ld "\n"
        write_type :: OutType -> IO ()
        write_type ty = do
          let fn = filePrefix ++ "." ++ show ty
          putIfVerbose opts 2 $ "Writing file: " ++ fn
          case ty of
            PrettyOut PrettyXml -> printXml fn
            PrettyOut PrettyAscii -> printAscii fn
            PrettyOut PrettyLatex -> writeLibDefnLatex opts ga fn ld
            _ -> return () -- implemented elsewhere
    putIfVerbose opts 3 ("Current OutDir: " ++ odir)
    mapM_ write_type $ outtypes opts

debugLatexFilename :: FilePath -> FilePath
debugLatexFilename =
    ( \ (b, p, _) -> p ++ b ++ ".debug.tex") . fileparse [".pp.tex"]

writeLibDefnLatex :: HetcatsOpts -> GlobalAnnos -> FilePath -> LIB_DEFN -> IO ()
writeLibDefnLatex opts ga oup ld =
    do let ldoc = toLatex ga $ pretty ld
       writeFile oup $ renderLatex Nothing ldoc
       doDump opts "DebugLatex" $
           writeFile (debugLatexFilename oup) $
               debugRenderLatex Nothing ldoc

toShATermString :: ShATermLG a => a -> IO String
toShATermString = fmap AT.writeSharedATerm . versionedATermTable

writeShATermFile :: ShATermLG a => FilePath -> a -> IO ()
writeShATermFile fp atcon = toShATermString atcon >>= writeFile fp

versionedATermTable :: ShATermLG a => a -> IO ATermTable
versionedATermTable atcon = do
    (att1, versionnr) <- toShATermLG emptyATermTable hetsVersion
    (att2, aterm) <- toShATermLG att1 atcon
    return $ fst $ addATerm (ShAAppl "hets" [versionnr, aterm] []) att2

writeShATermFileSDoc :: ShATermLG a => FilePath -> a -> IO ()
writeShATermFileSDoc fp atcon =
   versionedATermTable atcon >>= AT.writeSharedATermFile fp

writeFileInfo :: ShATermLG a => HetcatsOpts -> LIB_NAME
              -> FilePath -> LIB_DEFN -> a -> IO ()
writeFileInfo opts ln file ld gctx =
  let envFile = snd (getFilePrefix opts file) ++ envSuffix in
  case analysis opts of
  Basic -> do
      putIfVerbose opts 2 ("Writing file: " ++ envFile)
      catch (writeShATermFileSDoc envFile (ln, (ld, gctx))) $ \ err -> do
              putIfVerbose opts 2 (envFile ++ " not written")
              putIfVerbose opts 3 ("see following error description:\n"
                                   ++ shows err "\n")
  _ -> putIfVerbose opts 2 ("Not writing " ++ envFile)
