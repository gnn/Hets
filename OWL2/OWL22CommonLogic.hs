{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances #-}
{- |
Module      :  $Header$
Description :  Comorphism from OWL2 to Common Logic
Copyright   :  (c) Francisc-Nicolae Bungiu
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.bungiu@jacobs-university.de
Stability   :  provisional
Portability :  non-portable (via Logic.Logic)

a comorphism from OWL2 to CommonLogic
-}

module OWL2.OWL22CommonLogic (OWL22CommonLogic (..)) where

import Logic.Logic as Logic
import Logic.Comorphism
import qualified Common.AS_Annotation as CommonAnno
import Common.Result
import Control.Monad
import Data.Char
import Data.Maybe
import qualified Data.Set as Set
import qualified Data.Map as Map

-- OWL2 = domain
import OWL2.Logic_OWL2
import OWL2.AS
import OWL2.MS
import OWL2.ProfilesAndSublogics
import OWL2.Morphism
import OWL2.Symbols
import qualified OWL2.Sign as OS
-- CommonLogic = codomain
import Common.DocUtils
import CommonLogic.Logic_CommonLogic
import Common.Id as Id
import CommonLogic.AS_CommonLogic
import CommonLogic.Sign
import CommonLogic.Symbol
import qualified CommonLogic.Morphism as CLM
import qualified CommonLogic.Sublogic as ClSl

import Common.ProofTree

data OWL22CommonLogic = OWL22CommonLogic deriving Show

instance Language OWL22CommonLogic

instance Comorphism
    OWL22CommonLogic        -- comorphism
    OWL2                    -- lid domain
    ProfSub                  -- sublogics domain
    OntologyDocument        -- Basic spec domain
    Axiom                   -- sentence domain
    SymbItems               -- symbol items domain
    SymbMapItems            -- symbol map items domain
    OS.Sign                 -- signature domain
    OWLMorphism             -- morphism domain
    Entity                  -- symbol domain
    RawSymb                 -- rawsymbol domain
    ProofTree               -- proof tree codomain
    CommonLogic             -- lid codomain
    ClSl.CommonLogicSL      -- sublogics codomain
    BASIC_SPEC              -- Basic spec codomain
    TEXT                    -- sentence codomain
    NAME                    -- symbol items codomain
    SYMB_MAP_ITEMS          -- symbol map items codomain
    Sign                    -- signature codomain
    CLM.Morphism            -- morphism codomain
    Symbol                  -- symbol codomain
    Symbol                  -- rawsymbol codomain
    ProofTree               -- proof tree domain
    where
      sourceLogic OWL22CommonLogic = OWL2
      sourceSublogic OWL22CommonLogic = topS
      targetLogic OWL22CommonLogic = CommonLogic
      mapSublogic OWL22CommonLogic _ = Just ClSl.top
      map_theory OWL22CommonLogic = mapTheory
      map_morphism OWL22CommonLogic = mapMorphism
      map_symbol OWL22CommonLogic _ = mapSymbol
      isInclusionComorphism OWL22CommonLogic = True
      has_model_expansion OWL22CommonLogic = True

smap :: Monad m =>
        (t4 -> t -> t1 -> t2 -> m t3) -> t4 -> t -> t1 -> t2 -> m (t3, t4)
smap f s a b c = do
    x <- f s a b c
    return (x, s)

failMsg :: Pretty a => a -> Result b
failMsg a = fail $ "cannot translate " ++ showDoc a "\n"

hetsPrefix :: String
hetsPrefix = ""

voiToTok :: VarOrIndi -> Token
voiToTok v = case v of
    OVar o -> mkNName o
    OIndi o -> uriToTok o

uriToTokM :: IRI -> Result Token
uriToTokM = return . uriToTok

-- | Extracts Token from IRI
uriToTok :: IRI -> Token
uriToTok urI = mkSimpleId $ showQN urI

-- | Extracts Id from IRI
uriToId :: IRI -> Id
uriToId = simpleIdToId . uriToTok

mkQuants :: QUANT_SENT -> SENTENCE
mkQuants qs = Quant_sent qs nullRange

mkBools :: BOOL_SENT -> SENTENCE
mkBools bs = Bool_sent bs nullRange

mkAtoms :: ATOM -> SENTENCE
mkAtoms as = Atom_sent as nullRange

mkUnivQ :: [NAME_OR_SEQMARK] -> SENTENCE -> QUANT_SENT
mkUnivQ = Universal

mkExist :: [NAME_OR_SEQMARK] -> SENTENCE -> QUANT_SENT
mkExist = Existential

cnjct :: [SENTENCE] -> BOOL_SENT
cnjct = Conjunction

dsjct :: [SENTENCE] -> BOOL_SENT
dsjct = Disjunction

mkNeg :: SENTENCE -> BOOL_SENT
mkNeg = Negation

mkImpl :: SENTENCE -> SENTENCE -> BOOL_SENT
mkImpl = Implication

mkBicnd :: SENTENCE -> SENTENCE -> BOOL_SENT
mkBicnd = Biconditional

mkNAME :: Int -> NAME_OR_SEQMARK
mkNAME n = Name (mkNName n)

mkNTERM :: Int -> TERM
mkNTERM n = Name_term (mkNName n)

mkVTerm :: VarOrIndi -> TERM
mkVTerm = Name_term . voiToTok

mkTermSeq :: NAME -> TERM_SEQ
mkTermSeq = Term_seq . Name_term

senToText :: SENTENCE -> TEXT
senToText s = Text [Sentence s] nullRange

msen2Txt :: [SENTENCE] -> [TEXT]
msen2Txt = map senToText

mk1NTERM :: TERM
mk1NTERM = mkNTERM 1

mk1NAME :: NAME_OR_SEQMARK
mk1NAME = mkNAME 1

mkEq :: TERM -> TERM -> ATOM
mkEq = Equation

mk1QU :: SENTENCE -> SENTENCE
mk1QU = mkQuants . mkUnivQ [mk1NAME]

mkQU :: [NAME_OR_SEQMARK] -> SENTENCE -> SENTENCE
mkQU l = mkQuants . mkUnivQ l

mkBI :: SENTENCE -> SENTENCE -> SENTENCE
mkBI s = mkBools . mkImpl s

mkBN :: SENTENCE -> SENTENCE
mkBN = mkBools . mkNeg

mkBD :: [SENTENCE] -> SENTENCE
mkBD = mkBools . dsjct

mkBC :: [SENTENCE] -> SENTENCE
mkBC = mkBools . cnjct

mkBB :: SENTENCE -> SENTENCE -> SENTENCE
mkBB s = mkBools . mkBicnd s

mkQE :: [NAME_OR_SEQMARK] -> SENTENCE -> SENTENCE
mkQE l = mkQuants . mkExist l

mkSent :: [NAME_OR_SEQMARK] -> [NAME_OR_SEQMARK] -> SENTENCE -> SENTENCE
       -> SENTENCE
mkSent l1 l2 s = mkQU l1 . mkQE l2 . mkBI s

mkQUBI :: [NAME_OR_SEQMARK] -> [SENTENCE] -> TERM -> TERM -> TEXT
mkQUBI l1 l2 a b = senToText $ mkQU l1 $ mkBI (mkBC l2)
    $ mkAtoms $ mkEq a b

mkTermAtoms :: NAME -> [TERM] -> SENTENCE
mkTermAtoms ur tl = mkAtoms $ Atom (Name_term ur) $ map Term_seq tl

mkNName_H :: Int -> String
mkNName_H k = case k of
    0 -> ""
    j -> mkNName_H (j `div` 26) ++ [chr $ j `mod` 26 + 96]

-- | Build a name
mkNName :: Int -> Token
mkNName i = mkSimpleId $ hetsPrefix ++ mkNName_H i

-- | Get all distinct pairs for commutative operations
comPairs :: [t] -> [t1] -> [(t, t1)]
comPairs [] [] = []
comPairs _ [] = []
comPairs [] _ = []
comPairs (a : as) (_ : bs) = mkPairs a bs ++ comPairs as bs

mkPairs :: t -> [t1] -> [(t, t1)]
mkPairs a = map (\ b -> (a, b))

data VarOrIndi = OVar Int | OIndi IRI

-- | Mapping of OWL morphisms to CommonLogic morphisms
mapMorphism :: OWLMorphism -> Result CLM.Morphism
mapMorphism oMor = do
    dm <- mapSign $ osource oMor
    cd <- mapSign $ otarget oMor
    mapp <- mapMap $ mmaps oMor
    return (CLM.mkMorphism dm cd mapp)

mapMap :: Map.Map Entity IRI -> Result (Map.Map Id Id)
mapMap m = return $ Map.map uriToId $ Map.mapKeys entityToId m

mapSymbol :: Entity -> Set.Set Symbol
mapSymbol (Entity _ iri) = Set.singleton $ idToRaw $ uriToId iri

mapSign :: OS.Sign -> Result Sign
mapSign sig =
  let conc = Set.unions [ OS.concepts sig
                        , OS.datatypes sig
                        , OS.objectProperties sig
                        , OS.dataProperties sig
                        , OS.annotationRoles sig
                        , OS.individuals sig ]
      itms = Set.map uriToId conc
  in return emptySig { items = itms }

mapTheory :: (OS.Sign, [CommonAnno.Named Axiom])
             -> Result (Sign, [CommonAnno.Named TEXT])
mapTheory (owlSig, owlSens) = do
    cSig <- mapSign owlSig
    (cSensI, nSig) <- foldM (\ (x, y) z ->
              do
                (sen, sig) <- mapSentence y z
                return (sen ++ x, unite sig y)
                ) ([], cSig) owlSens
    return (nSig, cSensI)

-- | mapping of OWL to CommonLogic_DL formulae
mapSentence :: Sign                             -- ^ CommonLogic Signature
  -> CommonAnno.Named Axiom                     -- ^ OWL2 Sentence
  -> Result ([CommonAnno.Named TEXT], Sign)     -- ^ CommonLogic TEXT
mapSentence cSig inSen = do
    (outAx, outSig) <- mapAxioms cSig $ CommonAnno.sentence inSen
    return (map (flip CommonAnno.mapNamed inSen . const) outAx, outSig)

toIRILst :: EntityType -> Extended -> Maybe IRI
toIRILst ty ane = case ane of
  SimpleEntity (Entity ty2 iri) | ty == ty2 -> Just iri
  _ -> Nothing

-- | Extracts Id from Entities
entityToId :: Entity -> Id
entityToId (Entity _ iri) = uriToId iri

-- | Mapping of Class IRIs
mapClassIRI :: Sign -> Class -> Token -> Result SENTENCE
mapClassIRI _ uril uid = fmap (`mkTermAtoms` [Name_term uid]) $ uriToTokM uril

-- | Mapping of Individual IRIs
mapIndivIRI :: Sign -> Individual -> Result TERM
mapIndivIRI _ uriI = fmap Name_term $ uriToTokM uriI

-- | mapping of literals
mapLiteral :: Sign -> Literal -> Result TERM
mapLiteral _ c = do
    let cl = case c of
                Literal l _ -> l
                NumberLit l -> show l
    return $ Name_term $ mkSimpleId cl

-- | Mapping of a list of data constants only for mapDataRange
mapLiteralList :: Sign -> [Literal] -> Result [TERM]
mapLiteralList = mapM . mapLiteral

-- | mapping of individual list
mapComIndivList :: Sign -> SameOrDifferent -> Maybe Individual -> [Individual]
                -> Result [SENTENCE]
mapComIndivList cSig sod mol inds = do
    fs <- mapM (mapIndivIRI cSig) inds
    case mol of
        Nothing -> return $ comPairs fs fs
        Just ol -> fmap (`mkPairs` fs) $ mapIndivIRI cSig ol
    let inDL = comPairs fs fs
        sntLst = map (\ (x, y) -> case sod of
                    Same -> mkAtoms $ mkEq x y
                    Different -> mkBN $ mkAtoms $ mkEq x y) inDL
    return [mkBC sntLst]

mapDataPropI :: Sign -> VarOrIndi -> VarOrIndi -> DataPropertyExpression
             -> Result SENTENCE
mapDataPropI cSig nO nD dP = mapDataProp cSig dP nO nD

-- | Mapping of data properties
mapDataProp :: Sign -> DataPropertyExpression -> VarOrIndi -> VarOrIndi
            -> Result SENTENCE
mapDataProp _ dP a b = fmap (`mkTermAtoms` map mkVTerm [a, b])
    $ uriToTokM dP

mapComObjOrData :: (Sign -> a -> VarOrIndi -> VarOrIndi -> Result SENTENCE)
    -> Sign -> [a] -> VarOrIndi -> VarOrIndi -> Result [(SENTENCE, SENTENCE)]
mapComObjOrData f cSig props a b = mapM (\ (x, z) -> do
    l <- f cSig x a b
    r <- f cSig z a b
    return (l, r)) $ comPairs props props

-- | Mapping along DP List for creation of pairs for commutative operations
mapComDataPropsList :: Sign -> [DataPropertyExpression] -> VarOrIndi
    -> VarOrIndi -> Result [(SENTENCE, SENTENCE)]
mapComDataPropsList = mapComObjOrData mapDataProp

-- | Mapping along OP List for creation of pairs for commutative operations
mapComObjectPropsList :: Sign -> [ObjectPropertyExpression] -> VarOrIndi
    -> VarOrIndi -> Result [(SENTENCE, SENTENCE)]
mapComObjectPropsList = mapComObjOrData mapObjProp 

mapSubObjPropChain :: Sign -> [ObjectPropertyExpression] ->
        ObjectPropertyExpression -> Int -> Result SENTENCE
mapSubObjPropChain cSig props oP a = let b = a + 1 in do
    let zprops = zip (tail props) [(b + 1) ..]
        (_, vars) = unzip zprops
        vl = a : vars ++ [b]
    oProps <- mapM (\ (z, x, y) -> mapObjProp cSig z (OVar x) $ OVar y)
            $ zip3 props vl $ tail vl
    ooP <- mapObjProp cSig oP (OVar a) $ OVar b
    let lst = map mkNAME $ a : b : vars
    return $ mkQU lst $ mkBI (mkBC oProps) ooP

-- | Mapping of subobj properties
mapSubObjProp :: Sign -> ObjectPropertyExpression -> ObjectPropertyExpression
              -> Int -> Result SENTENCE
mapSubObjProp cSig prop oP a = do
    let b = a + 1
    l <- mapOPE cSig prop a b
    r <- mapOPE cSig oP a b
    return $ mkQU [mkNAME a, mkNAME b] $ mkBI l r

-- | Mapping of obj props
mapObjProp :: Sign -> ObjectPropertyExpression -> VarOrIndi -> VarOrIndi
            -> Result SENTENCE
mapObjProp cSig ob var1 var2 = case ob of
    ObjectProp u -> fmap (`mkTermAtoms` map mkVTerm [var1, var2]) $ uriToTokM u
    ObjectInverseOf u -> mapObjProp cSig u var2 var1

mapOPE :: Sign -> ObjectPropertyExpression -> Int -> Int -> Result SENTENCE
mapOPE cSig ope x y = mapObjProp cSig ope (OVar x) $ OVar y

mapDPE :: Sign -> DataPropertyExpression -> Int -> Int -> Result SENTENCE
mapDPE cSig dpe x y = mapDataProp cSig dpe (OVar x) $ OVar y

-- | Mapping of a list of descriptions
mapDescriptionList :: Sign -> Int -> [ClassExpression]
        -> Result ([SENTENCE], Sign)
mapDescriptionList cSig n lst = do
    (sens, lSig) <- mapAndUnzipM ((\ w x y z ->
                       mapDescription w z x y) cSig (OVar n) n) lst
    sig <- sigUnionL lSig
    return (sens, sig)

-- | Mapping of a list of pairs of descriptions
mapDescriptionListP :: Sign -> Int -> [(ClassExpression, ClassExpression)]
                    -> Result ([(SENTENCE, SENTENCE)], Sign)
mapDescriptionListP cSig n lst = do
    let (l, r) = unzip lst
    (llst, ssSig) <- mapDescriptionList cSig n l
    (rlst, tSig) <- mapDescriptionList cSig n r
    return (zip llst rlst, unite ssSig tSig)

-- | mapping of Data Range
mapDataRange :: Sign -> DataRange -> VarOrIndi -> Result (SENTENCE, Sign)
mapDataRange cSig rn inId = do
    let uid = mkVTerm inId
    case rn of
         DataJunction _ _ -> failMsg rn
         DataComplementOf dr -> do
            (dc, sig) <- mapDataRange cSig dr inId
            return (mkBN dc, sig)
         DataOneOf cs -> do
            cl <- mapLiteralList cSig cs
            dl <- mapM (\ x -> return $ mkAtoms $ Atom x [Term_seq uid]) cl
            return (mkBD dl, cSig)
         DataType dt rlst -> do
            let sent = mkTermAtoms (uriToTok dt) [uid]
            (sens, sigL) <- mapAndUnzipM (mapFacet cSig uid) rlst
            return (mkBC $ sent : sens, uniteL $ cSig : sigL)

-- | mapping of a tuple of ConstrainingFacet and RestictionValue
mapFacet :: Sign -> TERM -> (ConstrainingFacet, RestrictionValue)
         -> Result (SENTENCE, Sign)
mapFacet sig var (f, r) = do
    con <- mapLiteral sig r
    return (mkTermAtoms (uriToTok f) [con, var], unite sig $ emptySig
                   {items = Set.fromList [stringToId $ showQN f]})

-- | mapping of OWL Descriptions
mapDescription :: Sign -> ClassExpression -> VarOrIndi -> Int
               -> Result (SENTENCE, Sign)
mapDescription cSig des oVar aVar =
  let varN = case oVar of
        OVar v -> mkNName v
        OIndi i -> uriToTok i
      var = case oVar of
        OVar v -> v
        OIndi _ -> aVar
  in case des of
    Expression cl -> do
        rslt <- mapClassIRI cSig cl varN
        return (rslt, cSig)
    ObjectJunction jt desL -> do
        (desO, dSig) <- mapAndUnzipM ((\ w x y z -> mapDescription w z x y)
                            cSig oVar aVar) desL
        let un = uniteL dSig
        return $ case jt of
                UnionOf -> (mkBD desO, un)
                IntersectionOf -> (mkBC desO, un)
    ObjectComplementOf descr -> do
        (desO, dSig) <- mapDescription cSig descr oVar aVar
        return (mkBN desO, dSig)
    ObjectOneOf indS -> do
        indO <- mapM (mapIndivIRI cSig) indS
        let forms = map ((\ x y -> mkAtoms $ mkEq x y) $ Name_term varN) indO
        return (mkBD forms, cSig)
    ObjectValuesFrom qt oprop descr -> let v = var + 1 in do
        opropO <- mapObjProp cSig oprop (OVar var) $ OVar v
        (descO, dSig) <- mapDescription cSig descr (OVar v) $ aVar + 1
        return $ case qt of
            SomeValuesFrom ->
                (mkQuants $ mkExist [mkNAME v] $ mkBC [opropO, descO], dSig)
            AllValuesFrom ->
                (mkQuants $ mkUnivQ [mkNAME v] $ mkBI opropO descO, dSig)
    ObjectHasSelf oprop -> smap mapObjProp cSig oprop oVar oVar
    ObjectHasValue oprop indiv -> smap mapObjProp cSig oprop oVar (OIndi indiv)
    ObjectCardinality (Cardinality ct n oprop d) -> do
        let vlst = [(var + 1) .. (n + var)]
            vLst = map OVar vlst
            vlstM = [(var + 1) .. (n + var + 1)]
            vLstM = map OVar vlstM
        (dOut, sigL) <- (\ x -> case x of
            Nothing -> return ([], [])
            Just y -> mapAndUnzipM (uncurry $ mapDescription cSig y)
                                     $ zip vLst vlst) d
        let dlst = map (\ (x, y) -> mkBN $ mkAtoms
                    (mkEq (mkNTERM x) $ mkNTERM y)) $ comPairs vlst vlst
            dlstM = map (\ (x, y) -> mkAtoms (mkEq (mkNTERM x)
                     $ mkNTERM y)) $ comPairs vlstM vlstM
            qVars = map mkNAME vlst
            qVarsM = map mkNAME vlstM
        oProps <- mapM (mapObjProp cSig oprop $ OVar var) vLst
        oPropsM <- mapM (mapObjProp cSig oprop $ OVar var) vLstM
        let minLst = mkQE qVars $ mkBC $ dlst ++ dOut ++ oProps
            maxLst = mkQE qVarsM $ mkBI (mkBC $ oPropsM ++ dOut) $ mkBD dlstM
        return $ case ct of
                MinCardinality -> (minLst, cSig)
                MaxCardinality -> (maxLst, cSig)
                ExactCardinality -> (mkBC [minLst, maxLst], uniteL sigL)
    DataValuesFrom qt dpe dr -> do
        let varNN = mkNName $ var + 1
        (drSent, drSig) <- mapDataRange cSig dr $ OVar var
        senl <- mapM (mapDataPropI cSig (OVar var) $ OVar $ var + 1) [dpe]
        let sent = mkBC $ drSent : senl
        return $ case qt of
                    AllValuesFrom -> (mkQU [Name varNN] sent, drSig)
                    SomeValuesFrom -> (mkQE [Name varNN] sent, drSig)
    DataHasValue dpe c -> do
        let dpet = Name_term $ uriToTok dpe
        con <- mapLiteral cSig c
        return (mkQU [Name varN] $ mkAtoms $ Atom dpet
                    [mkTermSeq varN, Term_seq con], cSig)
    DataCardinality (Cardinality ct n dpe dr) -> do
        let vlst = [(var + 1) .. (n + var)]
            vLst = map OVar vlst
            vlstM = [(var + 1) .. (n + var + 1)]
            vLstM = map OVar vlstM
        (dOut, sigL) <- (\ x -> case x of
            Nothing -> return ([], [])
            Just y -> mapAndUnzipM (mapDataRange cSig y) vLst) dr
        let dlst = map ( \ (x, y) -> mkBN $ mkAtoms $ mkEq (mkNTERM x)
                        $ mkNTERM y) $ comPairs vlst vlst
            dlstM = map ( \ (x, y) -> mkAtoms $ mkEq (mkNTERM x) $ mkNTERM y)
                        $ comPairs vlstM vlstM
            qVars = map mkNAME vlst
            qVarsM = map mkNAME vlstM
        dProps <- mapM (mapDataProp cSig dpe $ OVar var) vLst
        dPropsM <- mapM (mapDataProp cSig dpe $ OVar var) vLstM
        let minLst = mkQE qVars $ mkBC $ dlst ++ dOut ++ dProps
            maxLst = mkQU qVarsM $ mkBI (mkBC $ dPropsM ++ dOut) $ mkBD dlstM
        return $ case ct of
                MinCardinality -> (minLst, cSig)
                MaxCardinality -> (maxLst, cSig)
                ExactCardinality -> (mkBC [minLst, maxLst], uniteL sigL)

mapClassAssertion :: TERM -> (ClassExpression, SENTENCE) -> TEXT
mapClassAssertion ind (ce, sent) = case ce of
    Expression _ -> senToText sent
    _ -> senToText $ (mk1QU . mkBI (mkAtoms $ mkEq mk1NTERM ind)) sent

mapFact :: Sign -> Extended -> Fact -> Result TEXT
mapFact cSig ex f = case f of
    ObjectPropertyFact posneg obe ind -> case ex of
        SimpleEntity (Entity NamedIndividual siri) -> do
            oPropH <- mapObjProp cSig obe (OIndi siri) (OIndi ind)
            let oProp = case posneg of
                            Positive -> oPropH
                            Negative -> mkBN oPropH
            return $ senToText oProp
        _ -> failMsg f
    DataPropertyFact posneg dpe lit -> case ex of
        SimpleEntity (Entity NamedIndividual iri) -> do
             inS <- mapIndivIRI cSig iri
             inT <- mapLiteral cSig lit
             nm <- uriToTokM dpe
             let dPropH = mkAtoms (Atom (Name_term nm)
                    [Term_seq inS, Term_seq inT])
                 dProp = case posneg of
                             Positive -> dPropH
                             Negative -> mkBN dPropH
             return $ senToText dProp
        _ -> failMsg f

mapCharact :: Sign -> ObjectPropertyExpression -> Character -> Result TEXT
mapCharact cSig ope c = case c of
    Functional -> do
        so1 <- mapOPE cSig ope 1 2
        so2 <- mapOPE cSig ope 1 3
        return $ mkQUBI (map mkNAME [1, 2, 3]) [so1, so2]
                (mkNTERM 2) (mkNTERM 3)
    InverseFunctional -> do
        so1 <- mapOPE cSig ope 1 3
        so2 <- mapOPE cSig ope 2 3
        return $ mkQUBI (map mkNAME [1, 2, 3]) [so1, so2]
                (mkNTERM 1) (mkNTERM 2)
    Reflexive -> do
        so <- mapOPE cSig ope 1 1
        return $ senToText $ mk1QU so
    Irreflexive -> do
        so <- mapOPE cSig ope 1 1
        return $ senToText $ mk1QU so
    Symmetric -> do
        so1 <- mapOPE cSig ope 1 2
        so2 <- mapOPE cSig ope 2 1
        return $ senToText $ mkQU [mkNAME 1, mkNAME 2] $ mkBI so1 so2
    Asymmetric -> do
        so1 <- mapOPE cSig ope 1 2
        so2 <- mapOPE cSig ope 2 1
        return $ senToText $ mkQU [mkNAME 1, mkNAME 2] $ mkBI so1 $ mkBN so2
    Antisymmetric ->  do
        so1 <- mapOPE cSig ope 1 2
        so2 <- mapOPE cSig ope 2 1
        return $ mkQUBI [mkNAME 1, mkNAME 2] [so1, so2] (mkNTERM 1) (mkNTERM 2)
    Transitive -> do
        so1 <- mapOPE cSig ope 1 2
        so2 <- mapOPE cSig ope 2 3
        so3 <- mapOPE cSig ope 1 3
        return $ senToText $ mkQU [mkNAME 1, mkNAME 2, mkNAME 3] $ mkBI
                (mkBC [so1, so2]) so3

-- | Mapping of ListFrameBit
mapListFrameBit :: Sign -> Extended -> Maybe Relation -> ListFrameBit
                -> Result ([TEXT], Sign)
mapListFrameBit cSig ex rel lfb = case lfb of
    AnnotationBit _a -> return ([], cSig)
    ExpressionBit cls -> case ex of
          Misc _ -> return ([], cSig)
          SimpleEntity (Entity ty iri) -> do
             ls <- mapM (\ (_, c) -> mapDescription
                        cSig c (OIndi iri) 1 ) cls
             case ty of
              NamedIndividual | rel == Just Types -> do
                  inD <- mapIndivIRI cSig iri
                  let ocls = map (mapClassAssertion inD)
                            $ zip (map snd cls) $ map fst ls
                  return (ocls, uniteL $ map snd ls)
              DataProperty | rel == (Just $ DRRelation ADomain) -> do
                  oEx <- mapDataProp cSig iri (OVar 1) (OVar 2)
                  return (msen2Txt $ map (mkSent [mk1NAME] [mkNAME 2] oEx)
                            $ map fst ls, uniteL $ map snd ls)
              _ -> failMsg cls
          ObjectEntity oe -> case rel of
              Nothing -> return ([], cSig)
              Just re -> case re of
                  DRRelation r -> do
                    tobjP <- mapObjProp cSig oe (OVar 1) (OVar 2)
                    tdsc <- mapM (\ (_, c) -> mapDescription cSig c (case r of
                            ADomain -> OVar 1
                            ARange -> OVar 2) (case r of
                            ADomain -> 1
                            ARange -> 2)) cls
                    let vars = case r of
                            ADomain -> (1, 2)
                            ARange -> (2, 1)
                    return (msen2Txt $ map (mkSent [mkNAME $ fst vars] 
                                [mkNAME $ snd vars] tobjP) $ map fst tdsc,
                            uniteL $ map snd tdsc)

                  _ -> failMsg cls
          ClassEntity ce -> do
            let map2nd = map snd cls
            case rel of
              Nothing -> return ([], cSig)
              Just r -> case r of
                EDRelation re -> do
                    (decrsS, dSig) <- mapDescriptionListP cSig 1
                      $ mkPairs ce map2nd
                    let decrsP = case re of
                         Equivalent -> map (\ (x, y) -> mkBB x y) decrsS
                         Disjoint -> map (\ (x, y) -> mkBN $ mkBC [x, y]) decrsS
                        snt = case decrsP of
                                [hd] -> hd
                                _ -> mkBC decrsP
                    return ([senToText $ mk1QU snt], dSig)
                SubClass -> do
                    (domT, dSig) <- mapDescription cSig ce (OVar 1) 1
                    ls <- mapM (\ cd -> mapDescription cSig cd (OVar 1) 1)
                                        map2nd
                    let
                      codT = map fst ls
                      eSig = map snd ls
                    rSig <- sigUnion cSig (unite dSig $ uniteL eSig)
                    return (msen2Txt $ map (mk1QU . mkBI domT) codT, rSig)
                _ -> failMsg cls

    ObjectBit ol ->
      let mol = fmap ObjectProp (toIRILst ObjectProperty ex)
          isJ = isJust mol
          Just ob = mol
          map2nd = map snd ol
      in case rel of
      Nothing -> return ([], cSig)
      Just r -> case r of
        EDRelation ed -> do
          pairs <- mapComObjectPropsList cSig map2nd (OVar 1) (OVar 2)
          let sntLst = case ed of
               Equivalent -> map (\ (x, y) -> mkBB x y) pairs
               Disjoint -> map (\ (x, y) -> mkBN $ mkBC [x, y]) pairs
              snt = case sntLst of
                        [hd] -> hd
                        _ -> mkBC sntLst
          return ([senToText $ mkQU [mkNAME 1, mkNAME 2] snt], cSig)

        SubPropertyOf | isJ -> do
          os <- mapM (\ (o1, o2) -> mapSubObjProp cSig o1 o2 3)
                $ mkPairs ob map2nd
          return (msen2Txt os, cSig)
        InverseOf | isJ -> do
            os1 <- mapM (\ o1 -> mapObjProp cSig o1 (OVar 1) (OVar 2)) map2nd
            o2 <- mapObjProp cSig ob (OVar 2) (OVar 1)
            return (msen2Txt $ map (\ cd -> mkQU [mkNAME 1, mkNAME 2]
                    $ mkBB cd o2) os1, cSig)
        _ -> return ([], cSig)
    DataBit db ->
      let mol = toIRILst DataProperty ex
          isJ = isJust mol
          map2nd = map snd db
          Just ob = mol
      in case rel of
      Nothing -> return ([], cSig)
      Just r -> case r of
        SubPropertyOf | isJ -> do
          os1 <- mapM (\ o1 -> mapDataProp cSig o1 (OVar 1) (OVar 2)) map2nd
          o2 <- mapDataProp cSig ob (OVar 1) (OVar 2)
          return (msen2Txt $ map (\ cd -> mkQU [mkNAME 1, mkNAME 2]
                $ mkBI cd o2) os1, cSig)
        EDRelation ed -> do
          pairs <- mapComDataPropsList cSig map2nd (OVar 1) (OVar 2)
          let sntLst = case ed of
                Equivalent -> map (\ (x, y) -> mkBB x y) pairs
                Disjoint -> map (\ (x, y) -> mkBN $ mkBC [x, y]) pairs
              snt = case sntLst of
                        [hd] -> hd
                        _ -> mkBC sntLst
          return ([senToText $ mkQU [mkNAME 1, mkNAME 2] snt], cSig)
        _ -> return ([], cSig)
    IndividualSameOrDifferent al -> do
        case rel of
          Nothing -> return ([], cSig)
          Just r -> case r of
              SDRelation re -> do
                fs <- mapComIndivList cSig re (toIRILst NamedIndividual ex)
                        $ map snd al
                return (msen2Txt fs, cSig)
              _ -> return ([], cSig)
    DataPropRange dpr -> case ex of
        SimpleEntity (Entity DataProperty iri) -> do
            oEx <- mapDataProp cSig iri (OVar 1) (OVar 2)
            ls <- mapM (\ (_, c) -> mapDataRange cSig c (OVar 2)) dpr
            let dSig = map snd ls
                odes = map fst ls
            return (msen2Txt $ map (mkSent [mkNAME 1] [mkNAME 2] oEx) odes
                               , uniteL dSig)
        _ -> failMsg dpr
    IndividualFacts indf -> do
        fl <- mapM (mapFact cSig ex . snd) indf
        return (fl, cSig)
    ObjectCharacteristics ace -> case ex of
        ObjectEntity ope -> do
            cl <- mapM (mapCharact cSig ope . snd) ace
            return (cl, cSig)
        _ -> failMsg ace

-- | Mapping of AnnFrameBit
mapAnnFrameBit :: Sign -> Extended -> AnnFrameBit -> Result ([TEXT], Sign)
mapAnnFrameBit cSig ex afb =
    let err = fail $ "could not translate " ++ show afb in case afb of
    AnnotationFrameBit _ -> return ([], cSig)
    DataFunctional -> case ex of
        SimpleEntity (Entity DataProperty iri) -> do
            so1 <- mapDPE cSig iri 1 2
            so2 <- mapDPE cSig iri 1 3
            return ([mkQUBI [mkNAME 1, mkNAME 2, mkNAME 3] [so1, so2]
                        (mkNTERM 2) $ mkNTERM 3], cSig)
        _ -> err
    DatatypeBit dt -> case ex of
        SimpleEntity (Entity Datatype iri) -> do
            (odes, dSig) <- mapDataRange cSig dt (OVar 2)
            dtb <- mapDPE cSig iri 1 2
            let res = mkQU [mkNAME 1, mkNAME 2] $ mkBB dtb odes
            return ([senToText res], dSig)
        _ -> err
    ClassDisjointUnion clsl -> case ex of
        SimpleEntity (Entity Class iri) -> do
            (decrs, dSig) <- mapDescriptionList cSig 1 clsl
            (decrsS, pSig) <- mapDescriptionListP cSig 1 $ comPairs clsl clsl
            let decrsP = unzip decrsS
            mcls <- mapClassIRI cSig iri (mkNName 1)
            return ([senToText $ mkQU [mkNAME 1] $ mkBB mcls $ mkBC
                    [mkBD decrs, mkBN $ mkBC $ uncurry (++) decrsP]],
                    unite dSig pSig)
        _ -> err
    ClassHasKey _ _ -> return ([], cSig)
    ObjectSubPropertyChain oplst -> do
        os <- mapM (\ cd -> mapSubObjPropChain cSig oplst cd 3) oplst
        return (msen2Txt os, cSig)

-- | Mapping of Axioms
mapAxioms :: Sign -> Axiom -> Result ([TEXT], Sign)
mapAxioms cSig (PlainAxiom ex fb) = case fb of
    ListFrameBit rel lfb -> mapListFrameBit cSig ex rel lfb
    AnnFrameBit _ afb -> mapAnnFrameBit cSig ex afb
