{- |
Module      :  $Header$
Copyright   :  (c) University of Cambridge, Cambridge, England
               adaption (c) Till Mossakowski, Uni Bremen 2002-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

Data structures for Isabelle signatures and theories.
   Adapted from Isabelle.


-}

module Isabelle.IsaSign where

import qualified Common.Lib.Map as Map

-------------------- not quite from src/Pure/term.ML ------------------------
----------------------------- Names -----------------------------------------

-- | type names
type TName = String

-- | names for values or constants (non-classes and non-types)
data VName = VName
    { new :: String -- ^ name within Isabelle
    , orig :: String  -- ^ original name from other logic
    } deriving Show

instance Eq VName where
    v1 == v2 = new v1 == new v2

instance Ord VName where
    v1 <= v2 = new v1 <= new v2

{- | Indexnames can be quickly renamed by adding an offset to the integer part,
     for resolution. -}
data Indexname = Indexname
    { unindexed :: String
    , indexOffset :: Int
    } deriving (Ord, Eq, Show)

--------- Classes
{- Types are classified by sorts. -}

data IsaClass  = IsaClass {classId :: String}
                 deriving (Ord, Eq, Show)

type Sort  = [IsaClass]

----------- Kinds

data ExKind = IKind IsaKind | IClass | PLogic

data IsaKind  = Star
              | Kfun IsaKind IsaKind
                deriving (Ord, Eq, Show)

------------------------------------------------------------------------------

{- The sorts attached to TFrees and TVars specify the sort of that variable -}
data Typ = Type  { typeId    :: TName,
                   typeSort  :: Sort,
                   typeArgs  :: [Typ] }
         | TFree { typeId    :: TName,
                   typeSort  :: Sort }
         | TVar  { indexname :: Indexname,
                   typeSort  :: Sort }
         deriving (Eq, Ord, Show)


{-Terms.  Bound variables are indicated by depth number.
  Free variables, (scheme) variables and constants have names.
  A term is "closed" if every bound variable of level "lev"
  is enclosed by at least "lev" abstractions.

  It is possible to create meaningless terms containing loose bound vars
  or type mismatches.  But such terms are not allowed in rules. -}

data Continuity = IsCont | NotCont deriving (Eq, Ord ,Show)

data Term =
        Const { termName     :: VName,
                termType     :: Typ }
      | Free  { termName   :: VName,
                termType     :: Typ }
      | Var  Indexname Typ
      | Bound Int
      | Abs   { absVar     :: Term,
                termType   :: Typ,
                termId     :: Term,
                continuity :: Continuity }  -- lambda abstraction
      | App  { funId :: Term,
               argId :: Term,
               continuity   :: Continuity }    -- application
      | MixfixApp { funId :: Term,
                    argIds :: [Term],
                    continuity   :: Continuity } -- mixfix application
      | If { ifId   :: Term,
             thenId :: Term,
             elseId :: Term,
             continuity :: Continuity }
      | Case { termId       :: Term,
               caseSubst    :: [(Term, Term)] }
      | Let { letSubst    :: [(Term, Term)],
              inId        :: Term }
      | IsaEq { firstTerm  :: Term,
                secondTerm :: Term }
      | Tuplex [Term] Continuity
      | Fix Term
      | Bottom
      | Paren Term
      | Wildcard
      deriving (Eq, Ord, Show)

data Sentence = Sentence { senTerm :: Term } -- axiom
              | Theorem { thmFlag :: Bool  -- True for "theorem"
                        , senTerm :: Term
                        , thmProof :: Maybe String }
              | ConstDef { senTerm :: Term }
              | RecDef { keyWord :: String
                       , senTerms :: [[Term]] }
                deriving (Eq, Ord, Show)

-------------------- from src/Pure/sorts.ML ------------------------

{-- type classes and sorts --}

{-  Classes denote (possibly empty) collections of types that are
  partially ordered by class inclusion. They are represented
  symbolically by strings.

  Sorts are intersections of finitely many classes. They are
  represented by lists of classes.  Normal forms of sorts are sorted
  lists of minimal classes (wrt. current class inclusion).

  (already defined in Pure/term.ML)

  classrel:
    table representing the proper subclass relation; entries (c, cs)
    represent the superclasses cs of c;

  arities:
    table of association lists of all type arities; (t, ars) means
    that type constructor t has the arities ars; an element (c, Ss) of
    ars represents the arity t::(Ss)c;
-}

type Classrel = Map.Map IsaClass (Maybe [IsaClass])
type Arities = Map.Map TName [(IsaClass, [(Typ, Sort)])]
type Abbrs = Map.Map TName ([TName], Typ)

data TypeSig =
  TySg {
    classrel:: Classrel,  -- domain of the map yields the classes
    defaultSort:: Sort,
    log_types:: [TName],
    univ_witness:: Maybe (Typ, Sort),
    abbrs:: Abbrs, -- constructor name, variable names, type.
    arities:: Arities }
    -- actually isa-instances. the former field tycons can be computed.
    deriving (Eq, Show)

emptyTypeSig :: TypeSig
emptyTypeSig = TySg {
    classrel = Map.empty,
    defaultSort = [],
    log_types = [],
    univ_witness = Nothing,
    abbrs = Map.empty,
    arities = Map.empty }

-------------------- from src/Pure/sign.ML ------------------------

data BaseSig = Main_thy  -- ^ main theory of higher order logic (HOL)
             | MainHC_thy  -- ^ extend main theory of HOL logic for HasCASL
             | HOLCF_thy   -- ^ higher order logic for continuous functions
             | HsHOLCF_thy  -- ^ HOLCF for Haskell
               deriving (Eq, Ord, Show)
             {- possibly simply supply a theory like MainHC as string
                or recursively as Isabelle.Sign -}

data Sign = Sign
    { baseSig :: BaseSig, -- like Main etc.
      tsig :: TypeSig,
      constTab :: ConstTab,  -- value cons with type
      domainTab :: DomainTab,
      dataTypeTab :: DataTypeTab,
      showLemmas :: Bool
    } deriving (Eq, Show)

 {- list of datatype definitions
    each of these consists of a list of (mutually recursive) datatypes
    each datatype consists of its name (Typ) and a list of constructors
    each constructor consists of its name (String) and list of argument types
 -}

type ConstTab = Map.Map VName Typ

type DataTypeTab = [DataTypeTabEntry]
type DataTypeTabEntry = [DataTypeEntry] -- (type,[value cons])
type DataTypeEntry = (Typ,[DataTypeAlt])
type DataTypeAlt = (VName,[Typ])

type DomainTab = [DomainTabEntry]
type DomainTabEntry = [DomainEntry] -- (type,[value cons])
type DomainEntry = (Typ,[DomainAlt])
type DomainAlt = (VName,[Typ])

emptySign :: Sign
emptySign = Sign { baseSig = Main_thy,
                   tsig = emptyTypeSig,
                   constTab = Map.empty,
                   dataTypeTab = [],
                   domainTab = [],
                   showLemmas = False }

------------------------ Sentence -------------------------------------

{- Instances in Haskell have form:

instance (MyClass a, MyClass b) => MyClass (MyTypeConst a b)

In Isabelle:

instance MyTypeConst :: (MyClass, MyClass) MyClass

Note that the Isabelle syntax does not allows for multi-parameter classes.
Rather, it subsumes the syntax for arities.

Type constraints are applied to value constructors in Haskell as follows:

MyValCon :: (MyClass a, MyClass b) => MyTypeConst a b

In Isabelle:

MyValCon :: MyTypeConst (a::MyClass) (b::MyClass)

In both cases, the typing expressions may be encoded as schemes.
Schemes and instances allows for the inference of type constraints over
values of functions.
-}
