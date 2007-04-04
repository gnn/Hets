{- |
Module      :  $Header$
Copyright   :  (c) University of Cambridge, Cambridge, England
               adaption (c) Till Mossakowski, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

Printing functions for Isabelle logic.
-}

module Isabelle.IsaPrint
    ( showBaseSig
    , printIsaTheory
    , getAxioms
    , printNamedSen
    ) where

import Isabelle.IsaSign
import Isabelle.IsaConsts

import Common.AS_Annotation
import qualified Data.Map as Map
import Common.Doc hiding (bar)
import Common.DocUtils

import Data.Char
import Data.List

printIsaTheory :: String -> String -> Sign -> [Named Sentence] -> Doc
printIsaTheory tn _ sign sens = let
    b = baseSig sign
    bs = showBaseSig b
    ld = "$HETS_LIB/Isabelle/"
    use = text usesS <+> doubleQuotes (text $ ld ++ "prelude")
    in text theoryS <+> text tn
    $+$ text importsS <+> (if case b of
                          Main_thy -> False
                          HOLCF_thy -> False
                          _ -> True then doubleQuotes
                                    $ text $ ld ++ bs else text bs)
    $+$ use
    $+$ text beginS
    $++$ printTheoryBody sign sens
    $++$ text endS

printTheoryBody :: Sign -> [Named Sentence] -> Doc
printTheoryBody sig sens =
    let (axs, rest) =
            getAxioms $ filter ( \ ns -> sentence ns /= mkSen true) sens
        (defs, rs) = getDefs rest
        (rdefs, ts) = getRecDefs rs
        tNames = map senName $ ts ++ axs
    in
    callML "initialize" (brackets $ sepByCommas
                        $ map (text . show . Quote) tNames) $++$
    printSign sig $++$
    (if null axs then empty else text axiomsS $+$
        vsep (map printNamedSen axs)) $++$
    (if null defs then empty else text defsS $+$
        vsep (map printNamedSen defs)) $++$
    vsep (map printNamedSen rdefs) $++$
    vcat (map ( \ a -> text declareS <+> text (senName a) 
                       <+> brackets (text simpS)) 
         $ filter ( \ a -> case sentence a of 
                      b@Sentence{} -> isSimp b
                      _ -> False) axs) $++$
    vsep (map ( \ t -> printNamedSen t $+$
                   text (case sentence t of
                         Sentence { thmProof = Just s } -> s
                         _ -> oopsS)
                  $++$ callML "record" (text $ show $ Quote $ senName t)) ts)

callML :: String -> Doc -> Doc
callML fun args =
    text mlS <+> doubleQuotes (fsep [text ("Header." ++ fun), args])

data QuotedString = Quote String
instance Show QuotedString where
    show (Quote s) = init . tail . show $ show s

getAxioms, getDefs, getRecDefs :: [Named Sentence] ->
                 ([Named Sentence], [Named Sentence])

getAxioms = partition ( \ s -> case sentence s of
                            Sentence {} -> isAxiom s
                            _ -> False)

getDefs = partition ( \ s -> case sentence s of
                            ConstDef {} -> True
                            _ -> False)

getRecDefs = partition ( \ s -> case sentence s of
                            RecDef {} -> True
                            _ -> False)

------------------- Printing functions -------------------

showBaseSig :: BaseSig -> String
showBaseSig = reverse . drop 4 . reverse . show

printClass :: IsaClass -> Doc
printClass (IsaClass x) = text x

printSort :: Sort -> Doc
printSort l = case l of
    [c] -> printClass c
    _ -> specBraces . hsep . punctuate comma $ map printClass l

data SynFlag = Quoted | Unquoted | Null

doubleColon :: Doc
doubleColon = text "::"

bar :: [Doc] -> [Doc]
bar = punctuate $ space <> text "|"

printType :: Typ -> Doc
printType = printTyp Unquoted

printTyp :: SynFlag -> Typ -> Doc
printTyp a = fst . printTypeAux a

printTypeAux :: SynFlag -> Typ -> (Doc, Int)
printTypeAux a t = case t of
 (TFree v s) -> (let d = text $ if isPrefixOf "\'" v || isPrefixOf "?\'" v
                                then v  else '\'' : v
                     c = printSort s
                 in if null s then d else case a of
   Quoted -> d <> doubleColon <> if null $ tail s then c else doubleQuotes c
   Unquoted -> d <> doubleColon <> c
   Null -> d, 1000)
 (TVar iv s) -> printTypeAux a $ TFree ("?\'" ++ unindexed iv) s
 (Type name _ args) -> case args of
   [t1, t2] | elem name [prodS, sProdS, funS, cFunS, sSumS] ->
       printTypeOp a name t1 t2
   _  -> ((case args of
           [] -> empty
           [arg] -> let (d, i) = printTypeAux a arg in
                      if i < 1000 then parens d else d
           _ -> parens $ hsep $ punctuate comma $
                       map (fst . printTypeAux a) args)
          <+> text name, 1000)

printTypeOp :: SynFlag -> TName -> Typ -> Typ -> (Doc, Int)
printTypeOp x name r1 r2 =
    let (d1, i1) = printTypeAux x r1
        (d2, i2) = printTypeAux x r2
        (l, r) = Map.findWithDefault (0 :: Int, 0 :: Int)
                    name $ Map.fromList
                    [ (funS, (1,0))
                    , (cFunS, (1,0))
                    , (sSumS, (11, 10))
                    , (prodS, (21, 20))
                    , (sProdS, (21, 20))
                    ]
        d3 = if i1 < l then parens d1 else d1
        d4 = if i2 < r then parens d2 else d2
    in (d3 <+> text name <+> d4, r)

and_docs :: [Doc] -> Doc
and_docs ds = vcat $ prepPunctuate (text andS <> space) ds

-- | printing a named sentence
printNamedSen :: Named Sentence -> Doc
printNamedSen ns =
  let s = sentence ns
      lab = senName ns
      b = isAxiom ns
      d = printSentence s 
  in case s of
  RecDef {} -> d
  _ -> let dd = doubleQuotes d in
       if isRefute s then text lemmaS <+> text lab <+> colon
              <+> dd $+$ text refuteS
       else if null lab then dd else fsep[ (case s of
    ConstDef {} -> text $ lab ++ "_def"
    Sentence {} ->
        (if b then empty else text theoremS)
        <+> text lab
    _ -> error "printNamedSen") <+> colon, dd]

-- | sentence printing
printSentence :: Sentence -> Doc
printSentence s = case s of
  RecDef kw xs -> text kw <+>
     and_docs (map (vcat . map (doubleQuotes . printTerm)) xs)
  _ -> printPlainTerm (not $ isRefute s) $ senTerm s

-- | print plain term
printTerm :: Term -> Doc
printTerm = printPlainTerm True

printPlainTerm :: Bool -> Term -> Doc
printPlainTerm b = fst . printTrm b

-- | print parens but leave a space if doc starts or ends with a bar
parensForTerm :: Doc -> Doc
parensForTerm d =
    let s = show d
        b = '|'
    in parens $ if null s then d
                else (if head s == b then (space <>) else id)
                         ((if last s == b then (<> space) else id) d)

printParenTerm :: Bool -> Int -> Term -> Doc
printParenTerm b i t = case printTrm b t of
    (d, j) -> if j < i then parensForTerm d else d

flatTuplex :: [Term] -> Continuity -> [Term]
flatTuplex cs c = case cs of
    [] -> cs
    _ -> case last cs of
           Tuplex rs@(_ : _ : _) d | d == c -> init cs ++ flatTuplex rs d
           _ -> cs

printMixfixAppl :: Bool -> Continuity -> Term -> [Term] -> (Doc, Int)
printMixfixAppl b c f args = case f of
        Const (VName n (Just (AltSyntax s is i))) _ -> let l = length is in
            case compare l $ length args of
               EQ -> if b || n == cNot || isPrefixOf "op " n then
                   (fsep $ replaceUnderlines s
                     $ zipWith (printParenTerm b) is args, i)
                   else printApp b c f args
               LT -> let (fargs, rargs) = splitAt l args
                         (d, p) = printMixfixAppl b c f fargs
                         e = if p < maxPrio - 1 then parensForTerm d else d
                     in printDocApp b c e rargs
               GT -> printApp b c f args
        Const vn _ | new vn `elem` [allS, exS, ex1S] -> case args of
            [Abs v t _] -> (fsep [text (new vn) <+> printPlainTerm False v
                    <> text "."
                    , printPlainTerm b t], lowPrio)
            _ -> printApp b c f args
        App g a d | c == d -> printMixfixAppl b c g (a : args)
        _ -> printApp b c f args

-- | print the term using the alternative syntax (if True)
printTrm :: Bool -> Term -> (Doc, Int)
printTrm b trm = case trm of
    Const vn ty -> let
        dvn = text $ new vn
        nvn = case ty of
            Type "!!!" [] [tx] ->
                parens $ dvn <+> doubleColon <+> printType tx
            _ | ty == noType -> dvn
            _ -> parens $ dvn <+> doubleColon <+> printType ty
      in case altSyn vn of
          Nothing -> (nvn, maxPrio)
          Just (AltSyntax s is i) -> if b && null is then
              (fsep $ replaceUnderlines s [], i) else (nvn, maxPrio)
    Free vn -> (text $ new vn, maxPrio)
    Abs v t c -> ((text $ case c of
        NotCont -> "%"
        IsCont -> "LAM") <+> printPlainTerm False v <> text "."
                    <+> printPlainTerm b t, lowPrio)
    If i t e c -> let d = fsep [printPlainTerm b i,
                        text "then" <+> printPlainTerm b t,
                        text "else" <+> printPlainTerm b e]
                  in case c of
        NotCont -> (text "if" <+> d, lowPrio)
        IsCont -> (text "If" <+> d <+> text "fi", maxPrio)
    Case e ps -> (text "case" <+> printPlainTerm b e <+> text "of"
        $+$ vcat (bar $ map (\ (p, t) ->
                 fsep [ printPlainTerm b p <+> text "=>"
                      , printParenTerm b (lowPrio + 1) t]) ps), lowPrio)
    Let es i -> (fsep [text "let" <+>
           vcat (punctuate semi $
                 map (\ (p, t) -> fsep [ printPlainTerm b p <+> text "="
                                       , printPlainTerm b t]) es)
           , text "in" <+> printPlainTerm b i], lowPrio)
    IsaEq t1 t2 -> (fsep [ printParenTerm b (isaEqPrio + 1) t1 <+> text "=="
                         , printParenTerm b isaEqPrio t2], isaEqPrio)
    Tuplex cs c -> ((case c of
        NotCont -> parensForTerm
        IsCont -> \ d -> text "<" <+> d <+> text ">") $
                        sepByCommas (map (printPlainTerm b) $ flatTuplex cs c)
                    , maxPrio)
    App f a c -> printMixfixAppl b c f [a]

printApp :: Bool -> Continuity -> Term -> [Term] -> (Doc, Int)
printApp b c t l = case l of
     [] -> printTrm b t
     _ -> printDocApp b c (printParenTerm b (maxPrio - 1) t) l

printDocApp :: Bool -> Continuity -> Doc -> [Term] -> (Doc, Int)
printDocApp b c d l =
    (fsep $ (case c of
          NotCont -> id
          IsCont -> punctuate $ text " $")
          $ d : map (printParenTerm b maxPrio) l
          , maxPrio - 1)

replaceUnderlines :: String -> [Doc] -> [Doc]
replaceUnderlines str l = case str of
    "" -> []
    '\'': r@(q : s) -> if q `elem` "_/'()"
                       then cons (text [q]) $ replaceUnderlines s l
                       else cons (text "'") $ replaceUnderlines r l
    '_' : r -> case l of
                  h : t -> cons h $ replaceUnderlines r t
                  _ -> error "replaceUnderlines"
    '/' : ' ' : r -> empty : replaceUnderlines r l
    q : r -> if q `elem` "()/" then replaceUnderlines r l
             else cons (text [q]) $ replaceUnderlines r l
  where
    cons :: Doc -> [Doc] -> [Doc]
    cons d r = case r of
                 [] -> [d]
                 h : t -> (d <> h) : t

-- end of term printing

printClassrel :: Classrel -> Doc
printClassrel = vcat . map ( \ (t, cl) -> case cl of
     Nothing -> empty
     Just x -> text axclassS <+> printClass t <+> text "<" <+>
                                           printSort x) . Map.toList

printArities :: String -> Arities -> Doc
printArities tn = vcat . map ( \ (t, cl) ->
                  vcat $ map (printInstance tn t) cl) . Map.toList

printInstance :: String -> TName -> (IsaClass, [(Typ, Sort)]) -> Doc
printInstance tn t xs = case xs of
   (IsaClass "Monad", _) ->
      if (isSuffixOf "_mh" tn) || (isSuffixOf "_mhc" tn)
      then printMInstance tn t
      else error "IsaPrint, printInstance: monads not supported"
   _ -> printNInstance t xs

printMInstance :: String -> TName -> Doc
printMInstance tn t = let thNm = text tn
                          thMorNm = text (t ++ "_tm")
                          tArrow = text ("-" ++ "->")
 in (text "thymorph" <+> thMorNm <+> colon <+>
            text "MonadType" <+> tArrow <+> thNm)
    $+$ text "  maps" <+> brackets
                 (parens $ (doubleQuotes $ text "MonadType.M")
                  <+> text "|->" <+> doubleQuotes (text $ tn ++ "." ++ t))
    $+$ text "t_instantiate Monad mapping" <+> thMorNm

{-
thymorph t : MonadType --> State maps [("MonadType.M" |-> "State.S")]
t_instantiate Monad mapping t
-}

printNInstance :: TName -> (IsaClass, [(Typ, Sort)]) -> Doc
printNInstance t xs = text instanceS <+> text t <> doubleColon <>
    (case snd xs of
     [] -> empty
     ys -> parens $ hsep $ punctuate comma
           $ map (doubleQuotes . printSort . snd) ys)
    <+> printClass (fst xs) $+$ text "by intro_classes"

-- filter out types that are given in the domain table
printTypeDecls :: DomainTab -> Arities -> Doc
printTypeDecls odt ars =
    let dt = Map.fromList $ map (\ (t, _) -> (typeId t, []))
             $ concat odt
    in vcat $ map printTycon $ Map.toList
           $ Map.difference ars dt

printTycon :: (TName, [(IsaClass, [(Typ, Sort)])]) -> Doc
printTycon (t, arity') =
              let arity = if null arity' then
                          error "IsaPrint.printTycon"
                                else length (snd $ head arity') in
            text typedeclS <+>
            (if arity > 0
             then parens $ hsep (map (text . ("'a"++) . show) [1..arity])
             else empty) <+> text t

-- | show alternative syntax (computed by comorphisms)
printAlt :: VName -> Doc
printAlt (VName _ altV) = case altV of
    Nothing -> empty
    Just (AltSyntax s is i) -> parens $ doubleQuotes (text s)
        <+> if null is then empty else text (show is) <+>
            if i == maxPrio then empty else text (show i)

instance Pretty Sign where
    pretty = printSign

-- | a dummy constant table with wrong types
constructors :: DomainTab -> ConstTab
constructors = Map.fromList . map (\ v -> (v, noType))
               . concatMap (map fst . snd) . concat

printSign :: Sign -> Doc
printSign sig = let dt = domainTab sig
                    ars = arities $ tsig sig
                in
    printTypeDecls dt ars $++$
    printClassrel (classrel $ tsig sig) $++$
    printDomainDefs dt $++$
    printConstTab (Map.difference (constTab sig)
                  $ constructors dt) $++$
    (if showLemmas sig then showCaseLemmata (domainTab sig) else empty) $++$
    printArities (theoryName sig) ars
    where
    printConstTab tab = if Map.null tab then empty else text constsS
                        $+$ vcat (map printConst $ Map.toList tab)
    printConst (vn, t) = text (new vn) <+> doubleColon <+>
                          doubleQuotes (printType t) <+> printAlt vn
    isDomain = case baseSig sig of
               HOLCF_thy -> True
               HsHOLCF_thy -> True
               MHsHOLCF_thy -> True
               _ -> False
    printDomainDefs dtDefs = vcat $ map printDomainDef dtDefs
    printDomainDef dts = if null dts then empty else
        text (if isDomain then domainS else datatypeS)
        <+> and_docs (map printDomain dts)
    printDomain (t, ops) =
       printTyp (if isDomain then Quoted else Null) t <+> equals <+>
       hsep (bar $ map printDOp ops)
    printDOp (vn, args) = let opname = new vn in
       text opname <+> hsep (map (printDOpArg opname)
                            $ zip args [1 :: Int .. ])
       <+> printAlt vn
    printDOpArg o (a, i) = let
      d = case a of
            TFree _ _ -> printTyp Null a
            _         -> doubleQuotes $ printTyp Null a
      in if isDomain then
           parens $ text (o ++ "_" ++ show i) <> doubleColon <> d
           else d
    showCaseLemmata dtDefs = text (concat $ map showCaseLemmata1 dtDefs)
    showCaseLemmata1 dts = concat $ map showCaseLemma dts
    showCaseLemma (_, []) = ""
    showCaseLemma (tyCons, (c:cons)) =
      let cs = "case caseVar of" ++ sp
          sc b = showCons b c ++ (concat $ map (("   | " ++)
                                                . (showCons b)) cons)
          clSome = sc True
          cl = sc False
          showCons b ((VName {new=cName}), args) =
            let pat = cName ++ (concat $ map ((sp ++) . showArg) args)
                            ++ sp ++ "=>" ++ sp
                term = showCaseTerm cName args
            in
               if b then pat ++ "Some" ++ sp ++ lb ++ term ++ rb ++ "\n"
                 else pat ++ term ++ "\n"
          showCaseTerm name args = if null name then sa
                                     else [toLower (head name)] ++ sa
            where sa = (concat $ map ((sp ++) . showArg) args)
          showArg (TFree [] _) = "varName"
          showArg (TFree (n:ns) _) = [toLower n] ++ ns
          showArg (TVar v s) = showArg (TFree (unindexed v) s)
          showArg (Type [] _ _) = "varName"
          showArg (Type m@(n:ns) _ s) =
            if m == "typeAppl" || m == "fun" || m == "*"
               then concat $ map showArg s
               else [toLower n] ++ ns
          showName (TFree v _) = v
          showName (TVar v _) = unindexed v
          showName (Type n _ _) = n
          proof = "apply (case_tac caseVar)\napply (auto)\ndone\n"
      in
        "lemma" ++ sp ++ "case_" ++ showName tyCons ++ "_SomeProm" ++ sp
                ++ "[simp]:\"" ++ sp ++ lb ++ cs ++ clSome ++ rb ++ sp
                ++ "=\n" ++ "Some" ++ sp ++ lb ++ cs ++ cl ++ rb ++ "\"\n"
                ++ proof

instance Pretty Sentence where
    pretty = printSentence

sp :: String
sp = " "

rb :: String
rb = ")"

lb :: String
lb = "("
