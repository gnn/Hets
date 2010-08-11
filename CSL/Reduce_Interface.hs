{- |
Module      :  $Header$
Description :  interface to Reduce CAS
Copyright   :  (c) Dominik Dietrich, DFKI Bremen, 2010
License     :  GPLv2 or higher

Maintainer  :  Dominik.Dietrich@dfki.de
Stability   :  provisional
Portability :  portable

Interface for Reduce CAS system.
-}

module CSL.Reduce_Interface where

import Common.AS_Annotation
import Common.Id

import Data.Time (midnight)

import Logic.Prover

import CSL.AS_BASIC_CSL
import CSL.Parse_AS_Basic
import CSL.Lemma_Export

import System.IO
import System.Process

type Session = (Handle, Handle)

-- | returns the name of the reduce prover
reduceS :: String
reduceS = "Reduce"

{- | returns a basic proof status for conjecture with name n
  where [EXPRESSION] represents the proof tree. -}
openReduceProofStatus :: String -> [EXPRESSION] -> ProofStatus [EXPRESSION]
openReduceProofStatus n = openProofStatus n reduceS

closedReduceProofStatus :: Ord pt => String -- ^ name of the goal
                -> pt -> ProofStatus pt
closedReduceProofStatus goalname proof_tree =
    ProofStatus
    { goalName = goalname
    , goalStatus = Proved True
    , usedAxioms = []
    , usedProver = reduceS
    , proofTree = proof_tree
    , usedTime = midnight
    , tacticScript = TacticScript "" }

{-
For Quantifier Elimination:
off nat;
load redlog;
rlset reals;

rlqe(exp...);
-}

-- | connects to the CAS, prepares the streams and sets initial options
connectCAS :: String -> IO (Handle, Handle, Handle, ProcessHandle)
connectCAS reducecmd = do
    putStrLn "succeeded"
    (inp, out, err, pid) <- runInteractiveCommand $ reducecmd ++ " -w"
    hSetBuffering out NoBuffering
    hSetBuffering inp LineBuffering
    hPutStrLn inp "off nat;"
    hPutStrLn inp "load redlog;"
    hPutStrLn inp "rlset reals;"
    hGetLine out
    hGetLine out
    hGetLine out
    hGetLine out
    hGetLine out
    hGetLine out
    hGetLine out
    putStrLn "done"
    return (inp, out, err, pid)

-- | closes the connection to the CAS
disconnectCAS :: (Handle, Handle) -> IO ()
disconnectCAS (inp, _) = do
  hPutStrLn inp "quit;"
  putStrLn "CAS disconnected"
  return ()


{- | reads characters from the specified output until the next result is
  complete, indicated by $ when using the maxima mode off nat; -}
getNextResultOutput :: Handle -> IO String
getNextResultOutput out = do
  b <- hIsEOF out
  if b then return "" else do
                        c <- hGetChar out
                        if c == '$' then return [] else do
                                                   r <- getNextResultOutput out
                                                   return (c : r)

exportExps :: [EXPRESSION] -> String
exportExps [] = ""
exportExps (e1 : e2 : e3) = exportExp e1 ++ "," ++ exportExps (e2 : e3)
exportExps (e1 : []) = exportExp e1

-- | those operators declared as infix in Reduce
infixOps :: [String]
infixOps = ["+", "-", "/", "**", "^", "=", "*", "and", "impl", "or"]

-- | exports an expression to Reduce format
exportExp :: EXPRESSION -> String
exportExp (Var token) = tokStr token
exportExp (Op s _ [e1, e2] _) =
  if elem s infixOps
  then "(" ++ exportExp e1 ++ s ++ exportExp e2 ++ ")"
  else s ++ "(" ++ exportExp e1 ++ "," ++ exportExp e2 ++ ")"
exportExp (Op s _ exps _) = s ++ if (length exps == 0) then "" else "(" 
                            ++ exportExps exps ++ 
                                 if (length exps == 0) then ")" else ""
exportExp (List exps _) = "{" ++ exportExps exps ++ "}"
exportExp (Int i _) = show i
exportExp (Double d _) = show d

-- | exports command to Reduce Format
exportReduce :: Named CMD -> String
exportReduce namedcmd = case sentence namedcmd of
  Cmd "simplify" exps -> exportExp $ head exps
  Cmd "ask" exps -> exportExp $ head exps
  Cmd cmd exps -> cmd ++ "(" ++ exportExps exps ++ ")"
  _ -> error "exportReduce: not implemented for this case" -- TODO: implement

procCmd :: (Handle, Handle) -> Named CMD
        -> IO (ProofStatus [EXPRESSION], [(Named CMD, ProofStatus [EXPRESSION])])
procCmd (inp, out) cmd = case cmdstring of
                                 "simplify" -> cassimplify (inp, out) cmd
                                 "ask" -> casask (inp, out) cmd
                                 "divide" -> casremainder (inp, out) cmd
                                 "rlqe" -> casqelim (inp, out) cmd
                                 "factorize" -> casfactorExp (inp, out) cmd
                                 "int" -> casint (inp, out) cmd
                                 "solve" -> cassolve (inp, out) cmd
                                 _ -> error "Command not supported"
    where Cmd cmdstring _ = sentence cmd

-- | removes the newlines 4: from the beginning of the string
skipReduceLineNr :: String -> String
skipReduceLineNr s = dropWhile (`elem` " \n") $ tail
                     $ dropWhile (/= ':') s

-- | sends the given string to the CAS, reads the result and tries to parse it.
procString :: (Handle, Handle) -> String -> String -> IO (ProofStatus [EXPRESSION])
procString (inp, out) axname s = do
  putStrLn $ "Send CAS cmd " ++ s
  hPutStrLn inp s
  res <- getNextResultOutput out
  putStrLn $ "Result is " ++ res
  putStrLn $ "Parsing of --" ++ skipReduceLineNr res ++ "-- yields "
    ++ show (parseResult (skipReduceLineNr res))
  case (parseResult (skipReduceLineNr res)) of
    Just e -> return $ closedReduceProofStatus axname [e]
    Nothing -> return $ openReduceProofStatus axname []


-- | factors a given expression over the reals
casfactorExp :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
casfactorExp (inp, out) cmd =
  do
    proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
    return (proofstatus,[exportLemmaFactor cmd proofstatus])

-- | solves a single equation over the reals
cassolve :: (Handle, Handle) -> Named CMD -> IO (ProofStatus [EXPRESSION],[(Named CMD, ProofStatus [EXPRESSION])])
cassolve (inp, out) cmd =
  do 
    proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
    return (proofstatus,[])
    



-- | simplifies a given expression over the reals
cassimplify :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
cassimplify (inp, out) cmd = do
  proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
  return (proofstatus,[exportLemmaSimplify cmd proofstatus])




-- | asks value of a given expression 
casask :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
casask (inp, out) cmd = do
  proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
  return (proofstatus,[exportLemmaAsk cmd proofstatus])


-- | computes the remainder of a division
casremainder :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
casremainder (inp, out) cmd =
  do
    proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce (makeNamed (senAttr cmd) (Cmd "divide" args)) ++ ";" 
    return (proofstatus,[exportLemmaRemainder cmd proofstatus])
  where Cmd _ args = sentence cmd

-- | integrates the given expression
casint :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
casint (inp, out) cmd =
  do
    proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
    return (proofstatus,[exportLemmaInt cmd proofstatus])

-- | performs quantifier elimination of a given expression
casqelim :: (Handle, Handle) -> Named CMD -> IO ((ProofStatus [EXPRESSION]),[(Named CMD, ProofStatus [EXPRESSION])])
casqelim (inp, out) cmd =
  do
    proofstatus <- procString (inp, out) (senAttr cmd) $ exportReduce cmd ++ ";"
    return (proofstatus,[exportLemmaQelim cmd proofstatus])


exportLemmaQelim :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaQelim namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

-- | declares an operator, such that it can used infix/prefix in CAS
casDeclareOperators :: (Handle, Handle) -> [EXPRESSION] -> IO ()
casDeclareOperators (inp, out) varlist = do
  hPutStrLn inp $ "operator " ++ exportExps varlist ++ ";"
  hGetLine out
  return ()

-- | declares an equation x := exp 
casDeclareEquation :: (Handle, Handle) -> CMD -> IO ()
casDeclareEquation (inp, out) (Cmd s exps) = 
  if s == ":=" then 
    do
      putStrLn $ (exportExp (exps !! 0)) ++ ":=" ++  (exportExp (exps !! 1))    
      hPutStrLn inp $ (exportExp (exps !! 0)) ++ ":=" ++  (exportExp (exps !! 1)) ++ ";"
      res <- getNextResultOutput out
      putStrLn $ "Declaration Result: " ++ res
      return ()
   else error "Expression is not an equation"

casDeclareEquation _ _ =
    error "casDeclareEquation: not implemented for this case" -- TODO: implement

-- | generates the lemma for cmd with result ProofStatus
exportLemmaFactor :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaFactor namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

exportLemmaSolve :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaSolve namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

exportLemmaSimplify :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaSimplify namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

exportLemmaAsk :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaAsk namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

exportLemmaRemainder :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaRemainder namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)


exportLemmaInt :: Named CMD -> ProofStatus [EXPRESSION] -> (Named CMD, ProofStatus [EXPRESSION])
exportLemmaInt namedcmd ps =
  ((makeNamed lemmaname lemma), closedReduceProofStatus lemmaname [(Op "Proof" [] [] nullRange)])
      where Cmd _ exps = sentence namedcmd
            lemma = Cmd "=" [head exps, head (proofTree ps)]
            lemmaname = (ganame namedcmd)

