{- |
Module      :  $Header$
Description :  reading and parsing ATerms, CASL, HetCASL files
Copyright   :  (c) Klaus L�ttich, C. Maeder, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(DevGraph)

reading and parsing ATerms, CASL, HetCASL files as much as is needed for the
static analysis
-}

module Driver.ReadFn where

import Logic.Grothendieck
import Syntax.AS_Library
import Syntax.Parse_AS_Library

import ATC.AS_Library ()
import ATC.GlobalAnnotations ()
import ATC.Sml_cats

import Driver.Options

import Common.ATerm.Lib
import Common.ATerm.ReadWrite
import Common.AnnoState
import Common.Id
import Common.Result
import Common.DocUtils
import Common.LibName

import Text.ParserCombinators.Parsec
import System.Time
import Data.List (isPrefixOf)

read_LIB_DEFN_M :: Monad m => LogicGraph -> HetcatsOpts
                -> FilePath -> String -> ClockTime -> m LIB_DEFN
read_LIB_DEFN_M lgraph opts file input mt =
    if null input then fail ("empty input file: " ++ file) else
    case intype opts of
    ATermIn _  -> return $ from_sml_ATermString input
    _ -> case runParser (library lgraph { currentLogic = defLogic opts })
          (emptyAnnos ()) file input of
         Left err  -> fail (showErr err)
         Right ast -> return $ setFilePath file mt ast

setFilePath :: FilePath -> ClockTime -> LIB_DEFN -> LIB_DEFN
setFilePath fp mt (Lib_defn ln lis r as) =
  Lib_defn ln { getLIB_ID = updFilePathOfLibId fp mt $ getLIB_ID ln } lis r as

readShATermFile :: ShATermConvertible a => FilePath -> IO (Result a)
readShATermFile fp = do
    str <- readFile fp
    return $ fromShATermString str

fromVersionedATT :: ShATermConvertible a => ATermTable -> Result a
fromVersionedATT att =
    case getATerm att of
    ShAAppl "hets" [versionnr,aterm] [] ->
        if hetsVersion == snd (fromShATermAux versionnr att)
        then Result [] (Just $ snd $ fromShATermAux aterm att)
        else Result [Diag Warning
                     "Wrong version number ... re-analyzing"
                     nullRange] Nothing
    _  ->  Result [Diag Warning
                   "Couldn't convert ShATerm back from ATermTable"
                   nullRange] Nothing

fromShATermString :: ShATermConvertible a => String -> Result a
fromShATermString str = if null str then
    Result [Diag Warning "got empty string from file" nullRange] Nothing
    else fromVersionedATT $ readATerm str

readVerbose :: ShATermConvertible a => HetcatsOpts -> LIB_NAME -> FilePath
            -> IO (Maybe a)
readVerbose opts ln file = do
    putIfVerbose opts 1 $ "Reading " ++ file
    Result ds mgc <- readShATermFile file
    showDiags opts ds
    case mgc of
      Nothing -> return Nothing
      Just (ln2, a) -> if ln2 == ln then return $ Just a else do
        putIfVerbose opts 0 $ "incompatible library names: "
               ++ showDoc ln " (requested) vs. "
               ++ showDoc ln2 " (found)"
        return Nothing

-- | create a file name without suffix from a library name
libNameToFile :: HetcatsOpts -> LIB_NAME -> FilePath
libNameToFile opts ln =
           case getLIB_ID ln of
                Indirect_link file _ ofile _ ->
                  let path = libdir opts
                     -- add trailing "/" if necessary
                  in if null ofile then pathAndBase path file else ofile
                Direct_link _ _ -> error "libNameToFile"

-- | convert a file name that may have a suffix to a library name
fileToLibName :: HetcatsOpts -> FilePath -> LIB_NAME
fileToLibName opts efile =
    let path = libdir opts
        file = rmSuffix efile -- cut of extension
        nfile = dropWhile (== '/') $         -- cut off leading slashes
                if isPrefixOf path file
                then drop (length path) file -- cut off libdir prefix
                else file
    in Lib_id $ Indirect_link nfile nullRange "" noTime
