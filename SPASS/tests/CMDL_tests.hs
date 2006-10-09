-- | test module similar to GUI_tests,
--   test ProveCMDL-functions
module CMDL_tests where 

import qualified Common.Lib.Map as Map 
import qualified Common.Lib.Set as Set 
import Common.Result
import qualified Control.Concurrent as Concurrent
import Data.IORef

import GUI.GenericATPState

import Common.AS_Annotation
import qualified Logic.Prover as LProver

import SPASS.Sign
import SPASS.Prove


printStatus :: IO [LProver.Proof_status ATP_ProofTree] -> IO ()
printStatus act = do st <- act
                     putStrLn (show st)

sign1 :: SPASS.Sign.Sign
sign1 = emptySign {sortMap = Map.insert "s" Nothing Map.empty,
                  predMap = Map.fromList (map (\ (x,y) -> (x, Set.singleton y) ) [("P",["s"]),("Q",["s"]),("R",["s"]),("A",["s"])])}

term_x :: SPTerm 
term_x = SPSimpleTerm (SPCustomSymbol "x")

axiom1 :: Named SPTerm
axiom1 = NamedSen "Ax" True False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPEquiv [SPComplexTerm (SPCustomSymbol "P") [term_x],SPComplexTerm (SPCustomSymbol "Q") [term_x]]))

axiom2 :: Named SPTerm
axiom2 = NamedSen "" True False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPImplies [SPComplexTerm (SPCustomSymbol "Q") [term_x],SPComplexTerm (SPCustomSymbol "R") [term_x]]))

axiom3 :: Named SPTerm
axiom3 = NamedSen "B$$-3" True False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPImplies [SPComplexTerm (SPCustomSymbol "Q") [term_x],SPComplexTerm (SPCustomSymbol "A") [term_x]]))

goal1 :: Named SPTerm
goal1 = NamedSen "Go" False False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPImplies [SPComplexTerm (SPCustomSymbol "Q") [term_x],SPComplexTerm (SPCustomSymbol "P") [term_x] ]))

goal2 :: Named SPTerm
goal2 = NamedSen "Go2" False False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPImplies [SPComplexTerm (SPCustomSymbol "P") [term_x],SPComplexTerm (SPCustomSymbol "R") [term_x] ]))

goal3 :: Named SPTerm
goal3 = NamedSen "Go3" False False (SPQuantTerm SPForall [term_x] (SPComplexTerm SPImplies [SPComplexTerm (SPCustomSymbol "P") [term_x],SPComplexTerm (SPCustomSymbol "A") [term_x] ]))


theory1 :: LProver.Theory SPASS.Sign.Sign SPTerm ATP_ProofTree
theory1 = (LProver.Theory sign1 $ LProver.toThSens [axiom1,-- axiom2,
                         goal1,goal2])

theory2 :: LProver.Theory SPASS.Sign.Sign SPTerm ATP_ProofTree
theory2 = (LProver.Theory sign1 $ LProver.toThSens [axiom1,axiom2,axiom3,
                         goal1,goal2,goal3])

-- A more complicated theory including ExtPartialOrder from Basic/RelationsAndOrders.casl
-- Not working though ...

signExt :: SPASS.Sign.Sign
signExt = emptySign {sortMap = {- Map.insert "Elem" Nothing -} Map.empty,
            funcMap = Map.fromList (map (\ (x,y) -> (x, Set.singleton y))
                                    [("gn_bottom",([],"Elem")),
                                     ("inf",(["Elem", "Elem"],"Elem")),
                                     ("sup",(["Elem", "Elem"],"Elem"))]),
            predMap = Map.fromList (map (\ (x,y) -> (x, Set.singleton y))
                                        [ ("gn_defined",["Elem"]),
                                          ("p__LtEq__",["Elem", "Elem"])] )}

ga_nonEmpty :: Named SPTerm
ga_nonEmpty = NamedSen {senName = "ga_nonEmpty", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPExists, variableList = [SPSimpleTerm (SPCustomSymbol "X")], qFormula = SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]}}}


ga_notDefBottom :: Named SPTerm
ga_notDefBottom = NamedSen {senName = "ga_notDefBottom", isAxiom = True, isDef = False, sentence = SPComplexTerm {symbol = SPNot, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_bottom", arguments = []}]}]}}

ga_strictness :: Named SPTerm
ga_strictness = NamedSen {senName = "ga_strictness", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPComplexTerm {symbol = SPCustomSymbol "inf", arguments = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")]}]},SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_one")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_two")]}]}]}}}

ga_strictness_one :: Named SPTerm
ga_strictness_one = NamedSen {senName = "ga_strictness_one", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPComplexTerm {symbol = SPCustomSymbol "sup", arguments = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")]}]},SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_one")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_two")]}]}]}}}

ga_predicate_strictness :: Named SPTerm
ga_predicate_strictness = NamedSen {senName = "ga_predicate_strictness", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X_one"),SPSimpleTerm (SPCustomSymbol "X_two")]},SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_one")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X_two")]}]}]}}}

antisym :: Named SPTerm
antisym = NamedSen {senName = "antisym", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "X")]}]},SPComplexTerm {symbol = SPEqual, arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]}]}]}}}

trans :: Named SPTerm
trans = NamedSen {senName = "trans", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "Z")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Z")]}]},SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "Z")]}]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Z")]}]}]}}}

refl :: Named SPTerm
refl = NamedSen {senName = "refl", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "X")]}]}}}

inf_def_ExtPartialOrder :: Named SPTerm
inf_def_ExtPartialOrder = NamedSen {senName = "inf_def_ExtPartialOrder", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "Z")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Z")]}]},SPComplexTerm {symbol = SPEquiv, arguments = [SPComplexTerm {symbol = SPEqual, arguments = [SPComplexTerm {symbol = SPCustomSymbol "inf", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPSimpleTerm (SPCustomSymbol "Z")]},SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Z"),SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Z"),SPSimpleTerm (SPCustomSymbol "Y")]}]},SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "T")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "T")]},SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "T"),SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "T"),SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "T"),SPSimpleTerm (SPCustomSymbol "Z")]}]}]}}]}]}]}}}

sup_def_ExtPartialOrder :: Named SPTerm
sup_def_ExtPartialOrder = NamedSen {senName = "sup_def_ExtPartialOrder", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "Z")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Z")]}]},SPComplexTerm {symbol = SPEquiv, arguments = [SPComplexTerm {symbol = SPEqual, arguments = [SPComplexTerm {symbol = SPCustomSymbol "sup", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPSimpleTerm (SPCustomSymbol "Z")]},SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Z")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "Z")]}]},SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "T")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "T")]},SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "T")]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "T")]}]},SPComplexTerm {symbol = SPCustomSymbol "p__LtEq__", arguments = [SPSimpleTerm (SPCustomSymbol "Z"),SPSimpleTerm (SPCustomSymbol "T")]}]}]}}]}]}]}}}

ga_comm_sup :: Named SPTerm
ga_comm_sup = NamedSen {senName = "ga_comm_sup", isAxiom = False, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPEqual, arguments = [SPComplexTerm {symbol = SPCustomSymbol "sup", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPComplexTerm {symbol = SPCustomSymbol "sup", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "X")]}]}]}}}

ga_comm_inf :: Named SPTerm
ga_comm_inf = NamedSen {senName = "ga_comm_inf", isAxiom = False, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")], qFormula = SPComplexTerm {symbol = SPImplies, arguments = [SPComplexTerm {symbol = SPAnd, arguments = [SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "X")]},SPComplexTerm {symbol = SPCustomSymbol "gn_defined", arguments = [SPSimpleTerm (SPCustomSymbol "Y")]}]},SPComplexTerm {symbol = SPEqual, arguments = [SPComplexTerm {symbol = SPCustomSymbol "inf", arguments = [SPSimpleTerm (SPCustomSymbol "X"),SPSimpleTerm (SPCustomSymbol "Y")]},SPComplexTerm {symbol = SPCustomSymbol "inf", arguments = [SPSimpleTerm (SPCustomSymbol "Y"),SPSimpleTerm (SPCustomSymbol "X")]}]}]}}}

gone :: Named SPTerm
gone = NamedSen {senName = "gone", isAxiom = False, isDef = False, sentence = SPSimpleTerm SPTrue}


theoryExt :: LProver.Theory SPASS.Sign.Sign SPTerm ATP_ProofTree
theoryExt = (LProver.Theory signExt $ LProver.toThSens [ga_nonEmpty, ga_notDefBottom, ga_strictness, ga_strictness_one, ga_predicate_strictness, antisym, trans, refl, inf_def_ExtPartialOrder, sup_def_ExtPartialOrder, gone, ga_comm_sup, ga_comm_inf])


runTest :: String -- ^ theory name
        -> LProver.Theory Sign Sentence ATP_ProofTree
        -> IO [LProver.Proof_status ATP_ProofTree]
runTest thName th = 
    do result <- spassProveCMDLautomatic
                              thName
                              (LProver.Tactic_script (show $ ATPTactic_script {
                                 ts_timeLimit = 20, ts_extraOpts = [] }))
                              th
       maybe (return [LProver.openProof_status "" "SPASS" (ATP_ProofTree "")])
             return
             (maybeResult result)

runTestBatch :: String -- ^ theory name
        -> LProver.Theory Sign Sentence ATP_ProofTree
        -> IO [LProver.Proof_status ATP_ProofTree]
runTestBatch thName th = 
    do resultRef <- newIORef (Result { diags = [], maybeResult = Just [] })
       (threadID, mvar) <- spassProveCMDLautomaticBatch
                               True True resultRef thName
                               (LProver.Tactic_script (show $ ATPTactic_script {
                                  ts_timeLimit = 20, ts_extraOpts = [] }))
                               th
       Concurrent.takeMVar mvar
       result <- readIORef resultRef
       maybe (return [LProver.openProof_status "" "SPASS" (ATP_ProofTree "")])
             return
             (maybeResult result)

test1 :: IO ()
test1 = printStatus (runTest "Foo1" theory1)
test1Batch :: IO ()
test1Batch = printStatus (runTestBatch "Foo1" theory1)

test2 :: IO ()
test2 = printStatus (runTest "Foo2" theory2)
test2Batch :: IO ()
test2Batch = printStatus (runTestBatch "Foo2" theory2)

testExt :: IO ()
testExt = printStatus (runTest "ExtPartialOrder" theoryExt)
testExtBatch :: IO ()
testExtBatch = printStatus (runTestBatch "ExtPartialOrder" theoryExt)
