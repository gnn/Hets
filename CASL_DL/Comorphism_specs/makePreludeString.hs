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
module Main where

import System.Environment

main :: IO ()
main = do
    let preludeFileName = "tmp.casl"
    preludeString <- readFile preludeFileName
    putStrLn (show preludeString)
