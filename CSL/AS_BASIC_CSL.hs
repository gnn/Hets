{-# LANGUAGE TypeSynonymInstances, FlexibleInstances #-}
{- |
Module      :  $Header$
Description :  Abstract syntax for CSL
Copyright   :  (c) Dominik Dietrich, Ewaryst Schulz, DFKI Bremen 2010
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Ewaryst.Schulz@dfki.de
Stability   :  experimental
Portability :  portable

This file contains the abstract syntax for CSL as well as pretty printer for it.

-}

module CSL.AS_BASIC_CSL
    ( EXPRESSION (..)     -- datatype for numerical expressions (e.g. polynomials)
    , EXTPARAM (..)       -- datatype for extended parameters (e.g. [I=0])
    , BASIC_ITEM (..)    -- Items of a Basic Spec
    , BASIC_SPEC (..)     -- Basic Spec
    , SYMB_ITEMS (..)     -- List of symbols
    , SYMB (..)           -- Symbols
    , SYMB_MAP_ITEMS (..) -- Symbol map
    , SYMB_OR_MAP (..)    -- Symbol or symbol map
    , OPNAME (..)         -- predefined operator names
    , OPID (..)           -- identifier for operators
    , ConstantName (..)   -- names of user-defined constants
    , OP_ITEM (..)        -- operator declaration
    , VAR_ITEM (..)       -- variable declaration
    , Domain (..)         -- domains for variable declarations
    , GroundConstant (..) -- constants for domain formation
    , AssDefinition (..)  -- A function or constant definition
    , getDefiniens        -- accessor function for AssDefinition
    , getArguments        -- accessor function for AssDefinition
    , isFunDef            -- predicate for AssDefinition
    , isInterval          -- predicate for EXPRESSION
    , mkDefinition        -- constructor for AssDefinition
    , updateDefinition    -- updates the definiens
    , InstantiatedConstant(..) -- for function constants we need to store the
                               -- instantiation
    , CMD (..)            -- Command datatype
    , OperatorState (..)  -- Class providing operator lookup
    , mapExpr             -- maps function over EXPRESSION arguments
    , mkVar               -- Variable constructor
    , mkOp                -- Simple Operator constructor
    , mkPredefOp          -- Simple Operator constructor for predefined ops
    , mkAndAnalyzeOp
    , toElimConst         -- Constant naming for elim constants, see Analysis.hs
    , OpInfo (..)         -- Type for Operator information
    , BindInfo (..)       -- Type for Binder information
    , operatorInfo        -- Operator information for pretty printing
                          -- and static analysis
    , operatorInfoMap     -- allows efficient lookup of ops by printname
    , operatorInfoNameMap -- allows efficient lookup of ops by opname
    , mergeOpArityMap     -- for combining two operator arity maps
    , getOpInfoMap
    , getOpInfoNameMap
    , lookupOpInfoForParsing
    , lookupBindInfo
    , APInt, APFloat      -- arbitrary precision numbers
    -- Printer
    , printExpression
    , printCMD
    , printAssDefinition
    , printConstantName
    , ExpressionPrinter (..)
    , toArgList
    , simpleName
    , showOPNAME
    , OpInfoMap
    , OpInfoNameMap
    ) where

import Common.Id as Id
import Common.Doc
import Common.DocUtils
import Common.AS_Annotation as AS_Anno
import qualified Data.Map as Map
import Control.Monad
import Control.Monad.Reader

import Data.Maybe


-- Arbitrary precision numbers
type APInt = Integer
-- TODO: use an arbitrary precision float here:
-- The use of Other floats (such as Double) requires an instance for
-- ShATermConvertible in Common.ATerm.ConvInstances
type APFloat = Double

-- | A simple operator constructor from given operator name and arguments
mkOp :: String -> [EXPRESSION] -> EXPRESSION
mkOp s el = Op (OpUser $ SimpleConstant s) [] el nullRange

-- | A variable constructor
mkVar :: String -> EXPRESSION
mkVar = Var . mkSimpleId

-- | A simple operator constructor from given operator id and arguments
mkPredefOp :: OPNAME -> [EXPRESSION] -> EXPRESSION
mkPredefOp n el = Op (OpId n) [] el nullRange

-- | Lookup the string in the given 'OperatorState'
mkAndAnalyzeOp :: OperatorState st => st -> String -> [EXTPARAM] -> [EXPRESSION]
               -> Range -> EXPRESSION
mkAndAnalyzeOp st s eps exps rg =
    let err msg = "mkAndAnalyzeOp: At operator " ++ s ++ "\n" ++ msg
        -- an error-message producing function
        g msg | not $ null eps = Just $ err msg
                                 ++ "* No extended parameters allowed\n"
              | null msg = Nothing
              | otherwise = Just $ err msg
        opOrErr mOp x = case x of
                          Just msg -> error msg
                          _ -> OpId $ opname $ fromJust mOp
        op = case lookupOperator st s (length exps) of
               Left False -> OpUser $ SimpleConstant s
               -- if registered it must be registered with the given arity or
               -- as flex-op, otherwise we don't accept it
               Left True -> opOrErr Nothing $ g "* Wrong arity\n"
               Right opinfo -> opOrErr (Just opinfo) $ g ""
    in Op op eps exps rg


mapExpr :: (EXPRESSION -> EXPRESSION) -> EXPRESSION -> EXPRESSION
mapExpr f e =
    case e of
      Op oi epl args rg -> Op oi epl (map f args) rg
      List exps rg -> List (map f exps) rg
      _ -> e


-- * CSL Basic Data Structures

-- | operator symbol declaration
data OP_ITEM = Op_item [Id.Token] Id.Range
               deriving Show

-- | variable symbol declaration
data VAR_ITEM = Var_item [Id.Token] Domain Id.Range
                deriving Show

newtype BASIC_SPEC = Basic_spec [AS_Anno.Annoted (BASIC_ITEM)]
                  deriving Show

data GroundConstant = GCI APInt | GCR APFloat deriving (Eq, Ord, Show)

-- | A finite set or an interval. True = closed, False = opened
data Domain = Set [GroundConstant]
            | IntVal (GroundConstant, Bool) (GroundConstant, Bool)
              deriving (Eq, Ord, Show)

-- | A constant or function definition
data AssDefinition = ConstDef EXPRESSION | FunDef [String] EXPRESSION
              deriving (Eq, Ord, Show)

updateDefinition :: EXPRESSION -> AssDefinition -> AssDefinition
updateDefinition e' (ConstDef _) = ConstDef e'
updateDefinition e' (FunDef l _) = FunDef l e'


mkDefinition :: [String] -> EXPRESSION -> AssDefinition
mkDefinition l e = if null l then ConstDef e else FunDef l e

getDefiniens :: AssDefinition -> EXPRESSION
getDefiniens (ConstDef e) = e
getDefiniens (FunDef _ e) = e

getArguments :: AssDefinition -> [String]
getArguments (FunDef l _) = l
getArguments _ = []

isFunDef :: AssDefinition -> Bool
isFunDef (FunDef _ _) = True
isFunDef _ = False

isInterval :: EXPRESSION -> Bool
isInterval (Interval _ _ _) = True
isInterval _ = False

data InstantiatedConstant = InstantiatedConstant
    { constName :: ConstantName
    , instantiation :: [EXPRESSION] } deriving (Show, Eq, Ord)

instance Pretty InstantiatedConstant where
    pretty (InstantiatedConstant { constName = cn, instantiation = el }) =
        if null el then pretty cn
        else pretty cn <> (parens $ sepByCommas $ map pretty el)

-- | basic items: an operator or variable declaration or an axiom
data BASIC_ITEM =
    Op_decl OP_ITEM
    | Var_decls [VAR_ITEM]
    | Axiom_item (AS_Anno.Annoted CMD)
    deriving Show

-- | Extended Parameter Datatype
data EXTPARAM = EP Id.Token String APInt deriving (Eq, Ord, Show)

data OPNAME =
    -- arithmetic operators
    OP_mult | OP_div | OP_plus | OP_minus | OP_neg | OP_pow
    -- roots, trigonometric and other operators
  | OP_fthrt | OP_sqrt | OP_abs | OP_max | OP_min | OP_sign
  | OP_cos | OP_sin | OP_tan | OP_Pi
  | OP_reldist

  -- special CAS operators
  | OP_minimize | OP_minloc | OP_maximize | OP_maxloc | OP_factor
  | OP_divide | OP_factorize | OP_int | OP_rlqe | OP_simplify | OP_solve

  -- comparison predicates
  | OP_neq | OP_lt | OP_leq | OP_eq | OP_gt | OP_geq | OP_convergence
  | OP_reldistLe

  -- containment predicate
  | OP_in

  -- special CAS constants
  | OP_undef | OP_failure

  -- boolean constants and connectives
  | OP_false | OP_true | OP_not | OP_and | OP_or | OP_impl

  -- quantifiers
  | OP_ex | OP_all

    deriving (Eq, Ord)

instance Show OPNAME where
    show = showOPNAME

showOPNAME :: OPNAME -> String
showOPNAME x =
        case x of
          OP_neq -> "!="
          OP_mult -> "*"
          OP_plus -> "+"
          OP_minus -> "-"
          OP_neg -> "-"
          OP_div -> "/"
          OP_lt -> "<"
          OP_leq -> "<="
          OP_eq -> "="
          OP_gt -> ">"
          OP_geq -> ">="
          OP_Pi -> "Pi"
          OP_pow -> "^"
          OP_abs -> "abs"
          OP_sign -> "sign"
          OP_all -> "all"
          OP_and -> "and"
          OP_convergence -> "convergence"
          OP_cos -> "cos"
          OP_divide -> "divide"
          OP_ex -> "ex"
          OP_factor -> "factor"
          OP_factorize -> "factorize"
          OP_fthrt -> "fthrt"
          OP_impl -> "impl"
          OP_int -> "int"
          OP_max -> "max"
          OP_maximize -> "maximize"
          OP_maxloc -> "maxloc"
          OP_min -> "min"
          OP_minimize -> "minimize"
          OP_minloc -> "minloc"
          OP_not -> "not"
          OP_or -> "or"
          OP_reldist -> "reldist"
          OP_reldistLe -> "reldistLe"
          OP_rlqe -> "rlqe"
          OP_simplify -> "simplify"
          OP_sin -> "sin"
          OP_solve -> "solve"
          OP_sqrt -> "sqrt"
          OP_tan -> "tan"
          OP_false -> "false"
          OP_true -> "true"
          OP_undef -> "undef"
          OP_failure -> "fail"
          OP_in -> "in"

data OPID = OpId OPNAME | OpUser ConstantName deriving (Eq, Ord, Show)

-- | We differentiate between simple constant names and indexed constant names
-- resulting from the extended parameter elimination.
data ConstantName = SimpleConstant String | ElimConstant String Int
                    deriving (Eq, Ord, Show)

simpleName :: OPID -> String
simpleName (OpId n) = showOPNAME n
simpleName (OpUser (SimpleConstant s)) = s
simpleName (OpUser x) = error "simpleName: ElimConstant not supported: " ++ show x

{-
instance Show OPID where
    show (OpId n) = show n
    show (OpUser s) = show s

instance Show ConstantName where
    show (SimpleConstant s) = s
    show (ElimConstant s i) = if i > 0 then s ++ "__" ++ show i else s
-}

toElimConst :: ConstantName -> Int -> ConstantName
toElimConst (SimpleConstant s) i = ElimConstant s i
toElimConst ec _ = error $ "toElimConst: already an elim const " ++ show ec

-- | Datatype for expressions
data EXPRESSION =
    Var Id.Token
  | Op OPID [EXTPARAM] [EXPRESSION] Id.Range
  -- TODO: don't need lists anymore, they should be removed soon
  | List [EXPRESSION] Id.Range
  | Interval APFloat APFloat Id.Range
  | Int APInt Id.Range
  | Double APFloat Id.Range
  deriving (Eq, Ord, Show)

-- | If the expression list is a variable list the list of the variable names
-- is returned.
toArgList :: [EXPRESSION] -> [String]
toArgList [] = []
toArgList (Var tok:l) = tokStr tok : toArgList l
toArgList (x:_) = error $ "toArgList: unsupported as argument " ++ show (pretty x)

-- TODO: add Range-support to this type
data CMD = Ass EXPRESSION EXPRESSION
         | Cmd String [EXPRESSION]
         | Sequence [CMD] -- program sequence
         | Cond [(EXPRESSION, [CMD])]
         | Repeat EXPRESSION [CMD] -- constraint, statements
           deriving (Show, Eq, Ord)

-- | symbol lists for hiding
data SYMB_ITEMS = Symb_items [SYMB] Id.Range
                  -- pos: SYMB_KIND, commas
                  deriving (Show, Eq)

-- | symbol for identifiers
newtype SYMB = Symb_id Id.Token
            -- pos: colon
            deriving (Show, Eq)

-- | symbol maps for renamings
data SYMB_MAP_ITEMS = Symb_map_items [SYMB_OR_MAP] Id.Range
                      -- pos: SYMB_KIND, commas
                      deriving (Show, Eq)

-- | symbol map or renaming (renaming then denotes the identity renaming)
data SYMB_OR_MAP = Symb SYMB
                 | Symb_map SYMB SYMB Id.Range
                   -- pos: "|->"
                   deriving (Show, Eq)

-- * Predefined Operators: info for parsing/printing and static analysis

data BindInfo = BindInfo { bindingVarPos :: [Int] -- ^ argument positions of
                                                  -- binding variables
                         , boundBodyPos :: [Int] -- ^ argument positions of
                                                 -- bound terms
                         } deriving (Eq, Ord, Show)

data OpInfo = OpInfo { prec :: Int -- ^ precedence between 0 and maxPrecedence
                     , infx :: Bool -- ^ True = infix
                     , arity :: Int -- ^ the operator arity
                     , opname :: OPNAME -- ^ The actual operator name
                     , bind :: Maybe BindInfo -- ^ More info for binders
                     } deriving (Eq, Ord, Show)

type ArityMap = Map.Map Int OpInfo
type OpInfoArityMap a = Map.Map a ArityMap
type OpInfoMap = OpInfoArityMap String
type OpInfoNameMap = OpInfoArityMap OPNAME


-- | Merges two OpInfoArityMaps together with the first map as default map
-- and the second overwriting the default values
mergeOpArityMap :: Ord a => OpInfoArityMap a -> OpInfoArityMap a
                -> OpInfoArityMap a
mergeOpArityMap = flip $ Map.unionWith Map.union


-- | Mapping of operator names to arity-'OpInfo'-maps (an operator may
--   behave differently for different arities).
getOpInfoMap :: (OpInfo -> String) -> [OpInfo] -> OpInfoMap
getOpInfoMap pf oinfo = foldl f Map.empty oinfo
    where f m oi = Map.insertWith Map.union (pf oi)
                   (Map.fromList [(arity oi, oi)]) m

-- | Same as operatorInfoMap but with keys of type OPNAME instead of String
getOpInfoNameMap :: [OpInfo] -> OpInfoNameMap
getOpInfoNameMap oinfo = foldl f Map.empty oinfo
    where f m oi = Map.insertWith Map.union (opname oi)
                   (Map.fromList [(arity oi, oi)]) m

-- | opInfoMap for the predefined 'operatorInfo'
operatorInfoMap :: OpInfoMap
operatorInfoMap = getOpInfoMap (show . opname) operatorInfo

-- | opInfoNameMap for the predefined 'operatorInfo'
operatorInfoNameMap :: OpInfoNameMap
operatorInfoNameMap = getOpInfoNameMap operatorInfo



-- | Mapping of operator names to arity-'OpInfo'-maps (an operator may
--   behave differently for different arities).
operatorInfo :: [OpInfo]
operatorInfo =
    let -- arity (-1 means flex), precedence, infix
        toSgl n i p = OpInfo { prec = if p == 0 then maxPrecedence else p
                             , infx = p > 0
                             , arity = i
                             , opname = n
                             , bind = Nothing
                             }
        toSglBind n i bv bb =
            OpInfo { prec = maxPrecedence
                   , infx = False
                   , arity = i
                   , opname = n
                   , bind = Just $ BindInfo [bv] [bb]
                   }
        -- arityX simple ops
        aX i s = toSgl s i 0
        -- arityflex simple ops
        aflex = aX (-1)
        -- arity2 binder
        a2bind bv bb s = toSglBind s 2 bv bb
        -- arity4 binder
        a4bind bv bb s = toSglBind s 4 bv bb
        -- arity2 infix with precedence
        a2i p s = toSgl s 2 p
    in map (aX 0) [ OP_failure, OP_undef, OP_Pi, OP_true, OP_false ]
           ++ map (aX 1)
                  [ OP_neg, OP_cos, OP_sin, OP_tan, OP_sqrt, OP_fthrt, OP_abs
                  , OP_sign, OP_simplify, OP_rlqe, OP_factor, OP_factorize ]
           ++ map (a2bind 0 1) [ OP_ex, OP_all ]
           ++ map (a2i 3) [ OP_or, OP_impl ]
           ++ map (a2i 4) [ OP_and ]
           ++ map (a2i 5) [ OP_eq, OP_gt, OP_leq, OP_geq, OP_neq, OP_lt, OP_in]
           ++ map (a2i 6) [ OP_plus ]
           ++ map (a2i 7) [ OP_minus ]
           ++ map (a2i 8) [OP_mult]
           ++ map (a2i 9) [OP_div]
           ++ map (a2i 10) [OP_pow]
           ++ map (aX 2)
                  [OP_int, OP_divide, OP_solve, OP_convergence, OP_reldist]
           ++ map (aX 3) [OP_reldistLe]
           ++ map aflex [ OP_min, OP_max ]
           ++ map (a2bind 1 0) [ OP_maximize, OP_minimize ]
           ++ map (a4bind 1 0) [ OP_maxloc, OP_minloc ]

maxPrecedence :: Int
maxPrecedence = 100


-- ---------------------------------------------------------------------------
-- * OpInfo lookup utils
-- ---------------------------------------------------------------------------

class OperatorState a where
    lookupOperator :: a
                   -> String -- ^ operator name
                   -> Int -- ^ operator arity
                   -> Either Bool OpInfo

instance OperatorState () where
    lookupOperator _ = lookupOpInfoForParsing operatorInfoMap

instance OperatorState OpInfoMap where
    lookupOperator = lookupOpInfoForParsing



-- | For the given name and arity we lookup an 'OpInfo', where arity=-1
-- means flexible arity. If an operator is registered for the given
-- string but not for the arity we return: Left True.
-- This function is designed for the lookup of operators in not statically
-- analyzed terms. For statically analyzed terms use lookupOpInfo.
lookupOpInfoForParsing :: OpInfoMap -- ^ map to be used for lookup
             -> String -- ^ operator name
             -> Int -- ^ operator arity
             -> Either Bool OpInfo
lookupOpInfoForParsing oiMap op arit =
    case Map.lookup op oiMap of
      Just oim ->
          case Map.lookup arit oim of
            Just x -> Right x
            Nothing ->
                case Map.lookup (-1) oim of
                  Just x -> Right x
                  _ -> Left True
      _ -> Left False

-- | For the given name and arity we lookup an 'OpInfo', where arity=-1
-- means flexible arity. If an operator is registered for the given
-- string but not for the arity we return: Left True.
lookupOpInfo :: OpInfoNameMap -> OPID -- ^ operator id
             -> Int -- ^ operator arity
             -> Either Bool OpInfo
lookupOpInfo oinm (OpId op) arit =
    case Map.lookup op oinm of
      Just oim ->
          case Map.lookup arit oim of
            Just x -> Right x
            Nothing ->
                case Map.lookup (-1) oim of
                  Just x -> Right x
                  _ -> Left True
      _ -> error $ "lookupOpInfo: no opinfo for " ++ show op
lookupOpInfo _ (OpUser _) _ = Left False

-- | For the given name and arity we lookup an 'BindInfo', where arity=-1
-- means flexible arity.
lookupBindInfo :: OpInfoNameMap -> OPID -- ^ operator name
             -> Int -- ^ operator arity
             -> Maybe BindInfo
lookupBindInfo oinm (OpId op) arit =
    case Map.lookup op oinm of
      Just oim ->
          case Map.lookup arit oim of
            Just x -> bind x
            _ -> Nothing
      _ -> error $ "lookupBindInfo: no opinfo for " ++ show op
lookupBindInfo _ (OpUser _) _ = Nothing

-- * Pretty Printing

instance Pretty Domain where
    pretty = printDomain
instance Pretty OP_ITEM where
    pretty = printOpItem
instance Pretty VAR_ITEM where
    pretty = printVarItem
instance Pretty BASIC_SPEC where
    pretty = printBasicSpec
instance Pretty BASIC_ITEM where
    pretty = printBasicItems
instance Pretty EXTPARAM where
    pretty = printExtparam
instance Pretty EXPRESSION where
    pretty = head . printExpression
instance Pretty SYMB_ITEMS where
    pretty = printSymbItems
instance Pretty SYMB where
    pretty = printSymbol
instance Pretty SYMB_MAP_ITEMS where
    pretty = printSymbMapItems
instance Pretty SYMB_OR_MAP where
    pretty = printSymbOrMap
instance Pretty CMD where
    pretty = head . printCMD
instance Pretty ConstantName where
    pretty = printConstantName
instance Pretty AssDefinition where
    pretty = head . printAssDefinition
instance Pretty OPID where
    pretty = head . printOPID


-- | A monad for printing of constants. This turns the pretty printing facility
-- more flexible w.r.t. the output of 'ConstantName'.
class Monad m => ExpressionPrinter m where
    getOINM :: m OpInfoNameMap
    getOINM = return operatorInfoNameMap
    printConstant :: ConstantName -> m Doc
    printConstant = return . printConstantName
    printOpname :: OPNAME -> m Doc
    printOpname = return . text . showOPNAME
    printInterval :: APFloat -> APFloat -> m Doc
    printInterval l r =
        return $ brackets $ sepByCommas $ map (text . show) [l, r]

-- | The default ConstantName printer
printConstantName :: ConstantName -> Doc
printConstantName (SimpleConstant s) = text s
printConstantName (ElimConstant s i) =
    text $ if i > 0 then s ++ "__" ++ show i else s

printAssDefinition :: ExpressionPrinter m => AssDefinition -> m Doc
printAssDefinition (ConstDef e) = printExpression e >>= return . (text "=" <+>)
printAssDefinition (FunDef l e) = do
  ed <- printExpression e
  return $ (parens $ sepByCommas $ map text l) <+> text "=" <+> ed

printOPID :: ExpressionPrinter m => OPID -> m Doc
printOPID (OpUser c) = printConstant c
printOPID (OpId oi) = printOpname oi

-- a dummy instance, we take the simplest monad
instance ExpressionPrinter []

-- | An 'OpInfoNameMap' can be interpreted as an 'ExpressionPrinter'
instance ExpressionPrinter (Reader OpInfoNameMap) where
    getOINM = ask


printCMD :: ExpressionPrinter m => CMD -> m Doc
printCMD (Ass c def) = do
  [c', def'] <- mapM printExpression [c, def]
  return $ c' <+> text ":=" <+> def'
printCMD c@(Cmd s exps) -- TODO: remove the case := later
    | s == ":=" = error $ "printCMD: use Ass for assignment representation! "
                  ++ show c
    | s == "constraint" = printExpression (exps !! 0)
    | otherwise = let f l = text s <> parens (sepByCommas l)
                  in liftM f $ mapM printExpression exps
printCMD (Repeat e stms) = do
  e' <- printExpression e
  let f l = text "re" <>
               (text "peat" $+$ vcat (map (text "." <+>)  l))
               $+$ text "until" <+> e'
  liftM f $ mapM printCMD stms

printCMD (Sequence stms) =
    let f l = text "se" <> (text "quence" $+$ vcat (map (text "." <+>) l))
              $+$ text "end"
    in liftM f $ mapM printCMD stms

printCMD (Cond l) = let f l' = vcat l' $+$ text "end"
                    in liftM f $ mapM (uncurry printCase) l

printCase :: ExpressionPrinter m => EXPRESSION -> [CMD] -> m Doc
printCase e l = do
  e' <- printExpression e
  let f l' = text "ca" <> (text "se" <+> e' <> text ":"
                                       $+$ vcat (map (text "." <+>)  l'))
  liftM f $ mapM printCMD l



getPrec :: OpInfoNameMap -> EXPRESSION -> Int
getPrec oinm (Op s _ exps _)
 | length exps == 0 = maxPrecedence + 1
 | otherwise =
     case lookupOpInfo oinm s $ length exps of
       Right oi -> prec oi
       Left True -> error $
                    concat [ "getPrec: registered operator ", show s, " used "
                           , "with non-registered arity ", show $ length exps ]
       _ -> maxPrecedence -- this is probably a userdefine prefix function
                          -- , binds strongly
getPrec _ _ = maxPrecedence

getOp :: EXPRESSION -> Maybe OPID
getOp (Op s _ _ _) = Just s
getOp _ = Nothing

printExtparam :: EXTPARAM -> Doc
printExtparam (EP p op i) =
    pretty p <> text op <> (text $ if op == "-|" then  "" else show i)

printExtparams :: [EXTPARAM] -> Doc
printExtparams [] = empty
printExtparams l = brackets $ sepByCommas $ map printExtparam l

printInfix :: ExpressionPrinter m => EXPRESSION -> m Doc
printInfix e@(Op s _ exps@[e1, e2] _) = do
-- we mustn't omit the space between the operator and its arguments for text-
-- operators such as "and", "or", but it would be good to omit it for "+-*/"
  oi <- printOPID s
  oinm <- getOINM
  let outerprec = getPrec oinm e
      f cmp e' ed = if cmp outerprec $ getPrec oinm e' then ed else parens ed
      g [ed1, ed2] = let cmp = case getOp e1 of
                                 Just op1 | op1 == s -> (<=)
                                          | otherwise -> (<)
                                 _ -> (<)
                     in f cmp e1 ed1 <+> oi <+> f (<) e2 ed2
      g _ = error "printInfix: Inner impossible case"
  liftM g $ mapM printExpression exps
printInfix _ = error "printInfix: Impossible case"

printExpression :: ExpressionPrinter m => EXPRESSION -> m Doc
printExpression (Var token) = return $ text $ tokStr token
printExpression e@(Op s epl exps _)
    | length exps == 0 = liftM (<> printExtparams epl) $ printOPID s
    | otherwise = do
        let f pexps = (<> (printExtparams epl <> parens (sepByCommas pexps)))
            asPrfx pexps = liftM (f pexps) $ printOPID s
            asPrfx' = mapM printExpression exps >>= asPrfx
        oinm <- getOINM
        case lookupOpInfo oinm s $ length exps  of
             Right oi
                 | infx oi -> printInfix e
                 | otherwise -> asPrfx'
             _ -> asPrfx'

printExpression (List exps _) = liftM sepByCommas (mapM printExpression exps)
printExpression (Int i _) = return $ text (show i)
printExpression (Double d _) = return $ text (show d)
printExpression (Interval l r _) = printInterval l r

printOpItem :: OP_ITEM -> Doc
printOpItem (Op_item tokens _) =
    text "operator" <+> sepByCommas (map pretty tokens)

printVarItem :: VAR_ITEM -> Doc
printVarItem (Var_item vars dom _) =
    hsep [sepByCommas $ map pretty vars, text "in", pretty dom]

printDomain :: Domain -> Doc
printDomain (Set l) = braces $ sepByCommas $ map printGC l
printDomain (IntVal (c1, b1) (c2, b2)) =
    hcat [ getIBorder True b1, sepByCommas $ map printGC [c1, c2]
         , getIBorder False b2]

getIBorder :: Bool -> Bool -> Doc
getIBorder False False = lbrack
getIBorder True True = lbrack
getIBorder _ _ = rbrack

printGC :: GroundConstant -> Doc
printGC (GCI i) = text (show i)
printGC (GCR d) = text (show d)

printBasicSpec :: BASIC_SPEC -> Doc
printBasicSpec (Basic_spec xs) = vcat $ map pretty xs

printBasicItems :: BASIC_ITEM -> Doc
printBasicItems (Axiom_item x) = pretty x
printBasicItems (Op_decl x) = pretty x
printBasicItems (Var_decls x) = text "vars" <+> (sepBySemis $ map pretty x)

printSymbol :: SYMB -> Doc
printSymbol (Symb_id sym) = pretty sym

printSymbItems :: SYMB_ITEMS -> Doc
printSymbItems (Symb_items xs _) = fsep $ map pretty xs

printSymbOrMap :: SYMB_OR_MAP -> Doc
printSymbOrMap (Symb sym) = pretty sym
printSymbOrMap (Symb_map source dest _) =
  pretty source <+> mapsto <+> pretty dest

printSymbMapItems :: SYMB_MAP_ITEMS -> Doc
printSymbMapItems (Symb_map_items xs _) = fsep $ map pretty xs


-- Instances for GetRange

instance GetRange OP_ITEM where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Op_item a b -> joinRanges [rangeSpan a, rangeSpan b]

instance GetRange VAR_ITEM where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Var_item a _ b -> joinRanges [rangeSpan a, rangeSpan b]


instance GetRange BASIC_SPEC where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Basic_spec a -> joinRanges [rangeSpan a]

instance GetRange BASIC_ITEM where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Op_decl a -> joinRanges [rangeSpan a]
    Var_decls a -> joinRanges [rangeSpan a]
    Axiom_item a -> joinRanges [rangeSpan a]

instance GetRange CMD where
    getRange = Range . rangeSpan
    rangeSpan (Ass c def) = joinRanges (map rangeSpan [c, def])
    rangeSpan (Cmd _ exps) = joinRanges (map rangeSpan exps)
    -- parsing guruantees l <> null
    rangeSpan (Repeat c l) = joinRanges [rangeSpan c, rangeSpan $ head l]
    -- parsing guruantees l <> null
    rangeSpan (Sequence l) = rangeSpan $ head l
    rangeSpan (Cond l) = rangeSpan $ head l

instance GetRange SYMB_ITEMS where
  getRange = Range . rangeSpan
  rangeSpan (Symb_items a b) = joinRanges [rangeSpan a, rangeSpan b]

instance GetRange SYMB where
  getRange = Range . rangeSpan
  rangeSpan (Symb_id a) = joinRanges [rangeSpan a]


instance GetRange SYMB_MAP_ITEMS where
  getRange = Range . rangeSpan
  rangeSpan (Symb_map_items a b) = joinRanges [rangeSpan a, rangeSpan b]

instance GetRange SYMB_OR_MAP where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Symb a -> joinRanges [rangeSpan a]
    Symb_map a b c -> joinRanges [rangeSpan a, rangeSpan b, rangeSpan c]

instance GetRange EXPRESSION where
  getRange = Range . rangeSpan
  rangeSpan x = case x of
    Var token -> joinRanges [rangeSpan token]
    Op _ _ exps a -> joinRanges $ [rangeSpan a] ++ (map rangeSpan exps)
    List exps a -> joinRanges $ [rangeSpan a] ++ (map rangeSpan exps)
    Int _ a -> joinRanges [rangeSpan a]
    Double _ a -> joinRanges [rangeSpan a]
    Interval _ _ a -> joinRanges [rangeSpan a]
