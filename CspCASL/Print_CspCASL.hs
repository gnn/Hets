{- |
Module      :  $Id$
Description :  Pretty printing for CspCASL
Copyright   :  (c) Andy Gimblett and Uni Bremen 2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  a.m.gimblett@swansea.ac.uk
Stability   :  provisional
Portability :  portable

Printing abstract syntax of CSP-CASL

-}
module CspCASL.Print_CspCASL where

import CASL.ToDoc ()

import Common.Doc
import Common.DocUtils
import Common.Keywords (colonS, elseS, ifS, thenS)

import CspCASL.AS_CspCASL
import CspCASL.AS_CspCASL_Process
import CspCASL.CspCASL_Keywords

instance Pretty CspBasicSpec where
    pretty = printCspBasicSpec

printCspBasicSpec :: CspBasicSpec -> Doc
printCspBasicSpec ccs =
    chan_part $+$ proc_part
        where chan_part = case (length chans) of
                            0 -> empty
                            1 -> (text channelS) <+> printChanDecs chans
                            _ -> (text channelsS) <+> printChanDecs chans
              proc_part = (text processS) <+>
                          (printProcItems (proc_items ccs))
              chans = channels ccs



printChanDecs :: [CHANNEL] -> Doc
printChanDecs cds = (vcat . punctuate semi . map pretty) cds

instance Pretty CHANNEL where
    pretty = printChanDecl

printChanDecl :: CHANNEL -> Doc
printChanDecl (Channel ns s) =
    (ppWithCommas ns) <+> (text colonS) <+> (pretty s)



printProcItems :: [PROC_ITEM] -> Doc
printProcItems ps = foldl ($+$) empty (map pretty ps)

instance Pretty PROC_ITEM where
    pretty = printProcItem

printProcItem :: PROC_ITEM -> Doc
printProcItem (ProcDecl pn args alpha) =
    (pretty pn) <> (printArgs args) <+> (text colonS) <+> (pretty alpha)
        where printArgs [] = empty
              printArgs a = parens $ ppWithCommas a
printProcItem (ProcEq pn p) =
    (pretty pn) <+> (text "=") <+> (pretty p)



instance Pretty PARM_PROCNAME where
    pretty = printParmProcname

printParmProcname :: PARM_PROCNAME -> Doc
printParmProcname (ParmProcname pn args) =
    pretty pn <> (printArgs args)
        where printArgs [] = empty
              printArgs a = parens $ ppWithCommas a



instance Pretty PROCESS where
    pretty = printProcess

printProcess :: PROCESS -> Doc
printProcess pr = case pr of
    -- precedence 0
    Skip -> text skipS
    Stop -> text stopS
    Div -> text divS
    Run es -> (text runS) <+> (pretty es)
    Chaos es -> (text chaosS) <+> (pretty es)
    NamedProcess pn es ->
        (pretty pn) <+> lparen <+> (ppWithCommas es) <+> rparen
    -- precedence 1
    ConditionalProcess f p q ->
        ((text ifS) <+> (pretty f) <+>
         (text thenS) <+> (glue pr p) <+>
         (text elseS) <+> (glue pr q)
        )
    -- precedence 2
    Hiding p es ->
        (pretty p) <+> (text hidingS) <+> (pretty es)
    RelationalRenaming p r ->
        ((pretty p) <+>
         (text renaming_openS) <+>
         (ppWithCommas r) <+>
         (text renaming_closeS))
    -- precedence 3
    Sequential p q ->
        (pretty p) <+> semi <+> (glue pr q)
    PrefixProcess ev p ->
        (pretty ev) <+> (text prefixS) <+> (glue pr p)
    InternalPrefixProcess v es p ->
        ((text internal_prefixS) <+> (pretty v) <+>
         (text colonS) <+> (pretty es) <+>
         (text prefixS) <+> (glue pr p)
        )
    ExternalPrefixProcess v es p ->
        ((text external_prefixS) <+> (pretty v) <+>
         (text colonS) <+> (pretty es) <+>
         (text prefixS) <+> (glue pr p)
        )
    -- precedence 4
    ExternalChoice p q ->
        (pretty p) <+> (text external_choiceS) <+> (glue pr q)
    InternalChoice p q ->
        (pretty p) <+> (text internal_choiceS) <+> (glue pr q)
    -- precedence 5
    Interleaving p q ->
        (pretty p) <+> (text interleavingS) <+> (glue pr q)
    SynchronousParallel p q ->
        (pretty p) <+> (text synchronousS) <+> (glue pr q)
    GeneralisedParallel p es q ->
        ((pretty p) <+> (text general_parallel_openS) <+>
         (pretty es) <+>
         (text general_parallel_closeS) <+> (glue pr q))
    AlphabetisedParallel p les res q ->
        ((pretty p) <+> (text alpha_parallel_openS) <+>
         (pretty les) <+> (text alpha_parallel_sepS) <+> (pretty res) <+>
         (text alpha_parallel_closeS) <+> (glue pr q)
        )

-- glue and prec_comp decide whether the child in the parse tree needs
-- to be parenthesised or not.  Parentheses are necessary if the
-- right-child is at the same level of precedence as the parent but is
-- a different operator; otherwise, they're not.

glue :: PROCESS -> PROCESS -> Doc
glue x y = if (prec_comp x y)
           then lparen <+> pretty y <+> rparen
           else pretty y

-- This is really nasty, but sledgehammer effective and allows fine
-- control.  Unmaintainable, however.  :-( I imagine there's a way to
-- compare the types in a less boilerplate manner, but OTOH there are
-- some special cases where it's nice to be explicit.  Also, hiding
-- and renaming are distinctly non-standard.  *shrug*

prec_comp :: PROCESS -> PROCESS -> Bool
prec_comp x y =
    case x of
      Hiding _ _ ->
          case y of RelationalRenaming _ _ -> True
                    _ -> False
      RelationalRenaming _ _ ->
          case y of Hiding _ _ -> True
                    _ -> False
      Sequential _ _ ->
          case y of InternalPrefixProcess _ _ _ -> True
                    ExternalPrefixProcess _ _ _ -> True
                    _ -> False
      PrefixProcess _ _ ->
          case y of Sequential _ _ -> True
                    _ -> False
      InternalPrefixProcess _ _ _ ->
          case y of Sequential _ _ -> True
                    _ -> False
      ExternalPrefixProcess _ _ _ ->
          case y of Sequential _ _ -> True
                    _ -> False
      ExternalChoice _ _ ->
          case y of InternalChoice _ _ -> True
                    _ -> False
      InternalChoice _ _ ->
          case y of ExternalChoice _ _ -> True
                    _ -> False
      Interleaving _ _ ->
          case y of SynchronousParallel _ _ -> True
                    GeneralisedParallel _ _ _ -> True
                    AlphabetisedParallel _ _ _ _ -> True
                    _ -> False
      SynchronousParallel _ _ ->
          case y of Interleaving _ _ -> True
                    GeneralisedParallel _ _ _ -> True
                    AlphabetisedParallel _ _ _ _ -> True
                    _ -> False
      GeneralisedParallel _ _ _ ->
          case y of Interleaving _ _ -> True
                    SynchronousParallel _ _ -> True
                    AlphabetisedParallel _ _ _ _ -> True
                    _ -> False
      AlphabetisedParallel _ _ _ _ ->
          case y of Interleaving _ _ -> True
                    SynchronousParallel _ _ -> True
                    GeneralisedParallel _ _ _ -> True
                    _ -> False
      _ -> False


instance Pretty EVENT where
    pretty = printEvent

printEvent :: EVENT -> Doc
printEvent (Event t) = pretty t

instance Pretty EVENT_SET where
    pretty = printEventSet

printEventSet :: EVENT_SET -> Doc
printEventSet (EventSet s) = pretty s
printEventSet EmptyEventSet = text "{}"
printEventSet FullAlphabet = empty -- XXX special, singleton anon only
                                   -- XXX but what to do really?

instance Pretty CSP_FORMULA where
    pretty = printCspFormula

printCspFormula :: CSP_FORMULA -> Doc
printCspFormula (Formula f) = pretty f
