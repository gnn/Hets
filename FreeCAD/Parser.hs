module FreeCAD.ParserTest
    where

import System.IO
import FreeCAD.Translator
import Data.Maybe
import Text.XML.Light.Input


--the IO part of the program:--
processFile = do
  xmlInput <-readFile "FreeCAD/input.xml"
  let parsed = parseXMLDoc xmlInput
  let out = translate (fromJust parsed)
  putStrLn (show out)
------------------------


