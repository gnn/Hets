{- |
Module      :  $Header$
Description :  Parser for CspCASL processes
Copyright   :  (c)
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  a.m.gimblett@swan.ac.uk
Stability   :  experimental
Portability :  portable

Parser for CSP-CASL processes.

-}

module CspCASL.Parse_CspCASL_Process
  ( channel_name
  , parens
  , parenList
  , cspStartKeys
  , cspSortId
  , parseCspId
  , csp_casl_process
  , event_set
  , process_name
  , var
  , commType
  , bracedList
  , procDeclOrDefn
  ) where

import Text.ParserCombinators.Parsec

import CASL.AS_Basic_CASL
import qualified CASL.Formula as CASL

import Common.AnnoState
import Common.Id
import Common.Keywords
import Common.Lexer
import Common.Parsec
import Common.Token (parseId, sortId, varId)

import CspCASL.AS_CspCASL_Process
import CspCASL.CspCASL_Keywords

csp_casl_process :: AParser st PROCESS
csp_casl_process = par_proc

cond_proc :: AParser st PROCESS
cond_proc = do
    ift <- asKey ifS
    f <- formula
    asKey thenS
    p <- csp_casl_process
    asKey elseS
    q <- csp_casl_process
    return $ ConditionalProcess f p q $ compRange ift q

par_proc :: AParser st PROCESS
par_proc = choice_proc >>= par_proc'

asKeySign :: String -> AParser st Token
asKeySign s =
  wrapAnnos . pToken $ tryString s
    << notFollowedBy (satisfy $ \ c -> elem c "[]" || isSignChar c)

par_proc' :: PROCESS -> AParser st PROCESS
par_proc' lp = do
    asKeySign interleavingS
    rp <- choice_proc
    par_proc' (Interleaving lp rp (compRange lp rp))
  <|> do
    asKeySign synchronousS
    rp <- choice_proc
    par_proc' (SynchronousParallel lp rp (compRange lp rp))
  <|> do
    asKeySign genpar_openS <|> asKeySign "|[" <|> asKeySign alpar_openS
    es <- event_set
    mes <- optionMaybe $ (asKeySign alpar_sepS <|> asKeySign barS)
      >> event_set
    asKeySign genpar_closeS <|> asKeySign "]|" <|> asKeySign alpar_closeS
    rp <- choice_proc
    par_proc' $ (case mes of
        Nothing -> GeneralisedParallel lp es
        Just res -> AlphabetisedParallel lp es res) rp $ compRange lp rp
  <|> return lp

choice_proc :: AParser st PROCESS
choice_proc = seq_proc >>= choice_proc'

choice_proc' :: PROCESS -> AParser st PROCESS
choice_proc' lp = do
    asKeySign external_choiceS
    rp <- seq_proc
    choice_proc' (ExternalChoice lp rp (compRange lp rp))
  <|> do
    asKeySign internal_choiceS
    rp <- seq_proc
    choice_proc' (InternalChoice lp rp (compRange lp rp))
  <|> return lp

seq_proc :: AParser st PROCESS
seq_proc = pref_proc >>= seq_proc'

cspStartKeys :: [String]
cspStartKeys = startCspKeywords ++ startKeyword

seqSym :: AParser st Token
seqSym = asKeySign sequentialS `notFollowedWith`
  (forget procDeclOrDefn <|> choice (map (forget . asKey) cspStartKeys))

seq_proc' :: PROCESS -> AParser st PROCESS
seq_proc' lp = do
    asKeySign doubleSemis <|> seqSym
    rp <- pref_proc
    seq_proc' (Sequential lp rp (compRange lp rp))
  <|> return lp

pref_proc :: AParser st PROCESS
pref_proc = do
    e <- event
    p <- pref_proc
    return (PrefixProcess e p (compRange e p))
  <|> hid_ren_proc <|> cond_proc

hid_ren_proc :: AParser st PROCESS
hid_ren_proc = prim_proc >>= hid_ren_proc'

hid_ren_proc' :: PROCESS -> AParser st PROCESS
hid_ren_proc' lp = do
    asKeySign hiding_procS
    es <- event_set
    hid_ren_proc' (Hiding lp es (compRange lp es))
  <|> do
    asKeySign ren_proc_openS
    rn <- renaming
    ck <- asKeySign ren_proc_closeS
    hid_ren_proc' (RenamingProcess lp rn (compRange lp ck))
  <|> return lp

-- | parser for parens
parens :: AParser st a -> AParser st a
parens p = oParenT >> p << cParenT

-- | parser for comma-separated items in parens
parenList :: AParser st a -> AParser st [a]
parenList = parens . commaSep1

prim_proc :: AParser st PROCESS
prim_proc = do
    pn <- process_name
    args <- procArgs
    return $ NamedProcess pn args $ compRange pn args
  <|> parens csp_casl_process
  <|> do
    rk <- asKey runS
    es <- parens event_set
    return $ Run es $ getRange rk
  <|> do
    ck <- asKey chaosS
    es <- parens event_set
    return $ Chaos es $ getRange ck
  <|> fmap (Div . getRange) (asKey divS)
  <|> fmap (Stop . getRange) (asKey stopS)
  <|> fmap (Skip . getRange) (asKey skipS)

-- | Parse a process name which can be a simple one or a fully qualified one.
process_name :: AParser st FQ_PROCESS_NAME
process_name = qualProc <|> fmap PROCESS_NAME processId

-- | Parse a process identifier
processId :: AParser st PROCESS_NAME
processId = do
  s <- var
  (c, p) <- option ([], nullRange) cspComps
  return (Id [s] c p)

cspComps :: AParser st ([Id], Range)
cspComps = try $ do
  o <- pToken $ string "[" << notFollowedBy (oneOf "[]|")
  (ts, ps) <- parseId cspKeywords `separatedBy` commaT
  c <- cBracketT
  return (ts, toRange o ps c)

channel_name :: AParser st CHANNEL_NAME
channel_name = cspSortId

-- List of arguments to a named process
procArgs :: AParser st [TERM ()]
procArgs = optionL $ parenList $ CASL.term cspKeywords

event_set :: AParser st EVENT_SET
event_set = do
    cts <- alphabet <?> "communication type"
    return (EventSet cts (getRange cts))

{- Events may be simple CASL terms or channel send/receives or
internal / external prefix choice. -}
event :: AParser st EVENT
event = ((prefixChoice <|> chanComm) << asKeySign prefix_procS)
        <|> try (term_event << asKeySign prefix_procS)

chanComm :: AParser st EVENT
chanComm = do
    (cn, sr) <- try $ pair channel_name
       $ asKeySign chan_sendS <|> asKeySign chan_receiveS
    if tokStr sr == chan_sendS then do
         v <- try $ var << asKeySign svar_sortS
         s <- cspSortId
         return (ChanNonDetSend cn v s (compRange cn s))
       <|> do
         t <- CASL.term cspKeywords
         return (ChanSend cn t (getRange cn))
       else do
         v <- var << asKeySign svar_sortS
         s <- cspSortId
         return (ChanRecv cn v s (compRange cn s))

prefixChoice :: AParser st EVENT
prefixChoice = do
    constr <- fmap (const InternalPrefixChoice) (asKeySign internal_choiceS)
      <|> fmap (const ExternalPrefixChoice) (asKeySign external_choiceS)
    v <- var
    asKeySign svar_sortS
    s <- cspSortId
    return $ constr v s $ getRange s

term_event :: AParser st EVENT
term_event = do
    t <- CASL.term cspKeywords
    return (TermEvent t (getRange t))

{- Formulas are CASL formulas.  We make our own wrapper around them
however. -}

formula :: AParser st (FORMULA ())
formula = CASL.formula cspKeywords

{- Primitive renaming is done using an operator name or a predicate
name.  They're both Ids.  Separation between operator or predicate
(or some other non-applicable Id) must be a static analysis
problem. -}

renaming :: AParser st RENAMING
renaming = fmap Renaming $ parseCspId `sepBy1` commaT

-- names come from CASL/Hets.

var :: AParser st VAR
var = varId cspKeywords

parseCspId :: AParser st Id
parseCspId = parseId cspKeywords

cspSortId :: AParser st SORT
cspSortId = sortId cspKeywords

-- Composition of ranges

compRange :: (GetRange a, GetRange b) => a -> b -> Range
compRange x y = getRange x `appRange` getRange y

-- * parse the beginning of a process declaration or equation

-- | parse many vars with the same sort
sortedVars :: AParser st (Either [SORT] VAR_DECL)
sortedVars = do
    is <- commaSep1 cspSortId
    ms <- optionMaybe $ pair colonT cspSortId
    case ms of
      Nothing -> return $ Left is
      Just (r, s) -> if all isSimpleId is
        then return $ Right $ Var_decl (map idToSimpleId is) s $ tokPos r else
        fail "expected only simple vars before colon"

-- | parse variables with possibly different sorts
manySortedVars :: AParser st (Either [SORT] [VAR_DECL])
manySortedVars = do
  e <- sortedVars
  case e of
    Left s -> return $ Left s
    Right vd -> do
       vs <- optionL $ anSemiOrComma
          >> fmap fst (CASL.varDecls cspKeywords)
       return $ Right $ vd : vs

-- | parse a sort or a sorted channel
commType :: AParser st CommType
commType = do
  s <- cspSortId
  do
    colonT
    r <- cspSortId
    return $ CommTypeChan $ TypedChanName s r
   <|> return (CommTypeSort s)

-- | parse a possibly empty list of comm types within braces
bracedList :: AParser st [CommType]
bracedList = braces $ sepBy commType commaT

-- | parse a set of comm types possibly within braces or the empty set
alphabet :: AParser st [CommType]
alphabet = bracedList <|> sepBy1 commType commaT

procTail :: AParser st PROC_ALPHABET
procTail = fmap ProcAlphabet $ colonT >> alphabet

procDecl :: AParser st FQ_PROCESS_NAME
procDecl = do
  pn <- processId
  ss <- optionL $ parenList cspSortId
  al <- procTail
  return $ FQ_PROCESS_NAME pn ss al

qualProc :: AParser st FQ_PROCESS_NAME
qualProc = do
    try (oParenT >> asKey processS)
    pd <- procDecl
    cParenT
    return pd

procDeclOrDefn :: AParser st (Either (FQ_PROCESS_NAME, [VAR])
    (PROCESS_NAME, Either [SORT] [VAR_DECL], PROC_ALPHABET))
procDeclOrDefn = do
    fqn <- qualProc
    as <- optionL $ parenList var
    equalT
    return $ Left (fqn, as)
  <|> do
    pn <- processId
    ma <- optionMaybe $ parens manySortedVars
    mal <- optionMaybe procTail
    case mal of
      Nothing -> do
        equalT
        case ma of
          Just (Left ss) | all isSimpleId ss ->
             return $ Left (PROCESS_NAME pn, map idToSimpleId ss)
          Nothing -> return $ Left (PROCESS_NAME pn, [])
          _ -> fail "unexpected argument list"
      Just al -> case ma of
        Nothing -> do
          me <- optionMaybe equalT
          case me of
            Nothing -> return $ Right (pn, Left [], al)
            Just _ -> return $ Right (pn, Right [], al)
        Just as -> case as of
          Left ss -> return $ Right (pn, Left ss, al)
          Right vds -> do
            equalT
            return $ Right (pn, Right vds, al)
