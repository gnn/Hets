module Main

where

import Syntax.Parse_AS_Library
import System.Environment
import Text.ParserCombinators.Parsec
import Common.AnnoState
import Comorphisms.LogicGraph
import Syntax.Print_HetCASL

parsefile fname = do
  input <- readFile fname
  case runParser (library (defaultLogic, logicGraph)) 
           (emptyAnnos defaultLogic) fname input of
            Left err -> error (show err)
            Right x -> putStrLn $ (show (printText0_eGA x)) ++ "\n..."


main = do
  files <- getArgs
  sequence (map parsefile files)


