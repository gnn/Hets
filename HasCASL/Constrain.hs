
{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003 
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  experimental
Portability :  portable 

constraint resolution

-}

module HasCASL.Constrain where

import HasCASL.Unify 
import HasCASL.As
import HasCASL.AsUtils
import HasCASL.Le
import HasCASL.TypeAna
import HasCASL.ClassAna

import qualified Common.Lib.Set as Set
import qualified Common.Lib.Map as Map
import qualified Common.Lib.Rel as Rel
import Common.Lib.State
import Common.PrettyPrint
import Common.Lib.Pretty
import Common.Keywords
import Common.Id
import Common.Result

import Data.List
import Data.Maybe

data Constrain = Kinding Type Kind
               | Subtyping Type Type 
		 deriving (Eq, Ord, Show)

instance PrettyPrint Constrain where
    printText0 ga c = case c of 
       Kinding ty k -> printText0 ga ty <+> colon 
				      <+> printText0 ga k
       Subtyping t1 t2 -> printText0 ga t1 <+> text lessS
				      <+> printText0 ga t2

instance PosItem Constrain where
  get_pos c = Just $ case c of 
    Kinding ty _ -> posOfType ty
    Subtyping t1 t2 -> firstPos [t1, t2] []

instance PosItem a => PosItem (Set.Set a)

type Constraints = Set.Set Constrain

noC :: Constraints
noC = Set.empty

joinC :: Constraints -> Constraints -> Constraints
joinC = Set.union

insertC :: Constrain -> Constraints -> Constraints
insertC = Set.insert

substC :: Subst -> Constraints -> Constraints
substC s = Set.image (\ c -> case c of
    Kinding ty k -> Kinding (subst s ty) k
    Subtyping t1 t2 -> Subtyping (subst s t1) $ subst s t2)


simplify :: TypeMap -> Constraints -> ([Diagnosis], Constraints)
simplify = postSimplify
{-
   let (ds, c2) = preSimplify tm cs
       (es, c3) = postSimplify tm c2
   in (ds ++ es, c3)
-}

postSimplify :: TypeMap -> Constraints -> ([Diagnosis], Constraints)
postSimplify tm rs = 
    if Set.isEmpty rs then ([], Set.empty)
    else let (r, rt) = Set.deleteFindMin rs 
	     Result ds m = entail tm r
             (es, cs) = postSimplify tm rt
             in (ds ++ es, case m of
                                 Just _ -> cs
	                         Nothing -> insertC r cs)

preSimplify :: TypeMap -> Constraints -> ([Diagnosis], Constraints)
preSimplify tm cs = 
    let subTys = toListC cs
        Result ds ms = mgu tm (map fst subTys) $ map snd subTys
    in case ms of 
    Nothing -> (mkDiag Error "non-unifiable subtyping constraints" subTys
                : ds, cs)  
    Just s -> (ds, substC s cs)
   
entail :: Monad m => TypeMap -> Constrain -> m ()
entail tm p = 
    do is <- byInst tm p
       mapM_ (entail tm) $ Set.toList is

byInst :: Monad m => TypeMap -> Constrain -> m Constraints
byInst tm c = case c of 
    Kinding ty k -> case ty of 
      ExpandedType _ t -> byInst tm $ Kinding t k
      _ -> case k of
	   Intersection l _ -> if null l then return noC else
			  do pss <- mapM (\ ik -> byInst tm (Kinding ty ik)) l 
			     return $ Set.unions pss
	   ExtKind ek _ _ -> byInst tm (Kinding ty ek)
	   ClassKind _ _ -> let (topTy, args) = getTypeAppl tm ty in
	       case topTy of 
	       TypeName _ kind _ -> if null args then
		   if lesserKind tm kind k then return noC 
		         else fail $ expected k kind
		   else do 
		       let ks = getKindAppl kind args
		       newKs <- dom tm k ks 
		       return $ Set.fromList $ zipWith Kinding args newKs
	       _ -> error "byInst: unexpected Type" 
	   _ -> error "byInst: unexpected Kind" 
    Subtyping t1 t2 -> if lesserType tm t1 t2 then return noC
--                       else if unify tm t1 t2 then return noC -- wrong!
                       else fail ("unable to prove: " ++ showPretty t1 " < " 
                                  ++ showPretty t2 "")

maxKind :: TypeMap -> Kind -> Kind -> Maybe Kind
maxKind tm k1 k2 = if lesserKind tm k1 k2 then Just k1 else 
		if lesserKind tm k2 k1 then Just k2 else Nothing

maxKinds :: TypeMap -> [Kind] -> Maybe Kind
maxKinds tm l = case l of 
    [] -> Nothing
    [k] -> Just k
    [k1, k2] -> maxKind tm k1 k2
    k1 : k2 : ks -> case maxKind tm k1 k2 of 
          Just k -> maxKinds tm (k : ks)
	  Nothing -> do k <- maxKinds tm (k2 : ks)
			maxKind tm k1 k 

maxKindss :: TypeMap -> [[Kind]] -> Maybe [Kind]
maxKindss tm l = let margs = map (maxKinds tm) $ transpose l in
   if all isJust margs then Just $ map fromJust margs
      else Nothing

dom :: Monad m => TypeMap -> Kind -> [(Kind, [Kind])] -> m [Kind]
dom tm k ks = 
    let fks = filter ( \ (rk, _) -> lesserKind tm rk k ) ks 
	margs = maxKindss tm $ map snd fks
        in if null fks then fail ("class not found " ++ showPretty k "") 
           else case margs of 
	      Nothing -> fail "dom: maxKind"
	      Just args -> if any ((args ==) . snd) fks then return args
			   else fail "dom: not coregular"

-- | get kind of an analyzed type
kindOfType :: TypeMap -> Type -> Kind
kindOfType tm ty = case ty of 
    TypeName _ k _ -> k
    TypeAppl t1 t2 -> toIntersection 
                (concatMap snd $ getKindAppl (kindOfType tm t1) [t2]) 
                [posOfType t1, posOfType t2]
    ExpandedType _ t1 -> kindOfType tm t1
    FunType t1 a t2 _ -> 
       let i = arrowId a
           Result _ mk = getIdKind tm i in case mk of
       Just k -> let tn = TypeName i k 0 in 
           kindOfType tm (TypeAppl (TypeAppl tn t1) t2)
       Nothing -> error "kindOfType: FunType" 
    ProductType ts ps -> let Result _ mk = getIdKind tm productId in case mk of
            Nothing -> error "kindOfType: ProductType" 
            Just k -> let 
                rk = toIntersection (map fst $ getKindAppl k [ty,ty]) ps
                tn = TypeName productId k 0 
		mkAppl [t1] = t1
                mkAppl (t1:tr) = TypeAppl (TypeAppl tn t1) $ mkAppl tr
		mkAppl [] = error "kindOfType: mkAppl"
                in if null ts then rk else kindOfType tm (mkAppl ts)
    LazyType t _ -> kindOfType tm t
    KindedType _ k _ -> k
    _ -> error "kindOfType"

freshTypeVarT :: TypeMap -> Type -> State Int Type             
freshTypeVarT tm t = 
    do (var, c) <- freshVar $ posOfType t
       return $ TypeName var (kindOfType tm t) c

freshVarsT :: TypeMap -> [Type] -> State Int [Type]
freshVarsT tm l = mapM (freshTypeVarT tm) l

toPairState :: State Int a -> State (Int, b) a 
toPairState p = 
    do (a, b) <- get
       let (r, c) = runState p a
       put (c, b)
       return r 

addSubst :: Subst -> State (Int, Subst) ()
addSubst s = do 
    (c, o) <- get
    put (c, compSubst o s)

swap :: (a, b) -> (b, a)
swap (a, b) = (b, a)

-- pre: shapeMatch succeeds
shapeMgu :: TypeMap -> [(Type, Type)] -> State (Int, Subst) [(Type, Type)]
shapeMgu tm cs = 
    let (atoms, structs) = partition ( \ p -> case p of
                                       (TypeName _ _ _, TypeName _ _ _) -> True
                                       _ -> False) cs 
    in if null structs then return atoms else
    let p@(t1, t2) = head structs
        tl = tail structs 
        rest = tl ++ atoms
    in case p of 
    (ExpandedType _ t, _) -> shapeMgu tm ((t, t2) : rest)
    (_, ExpandedType _ t) -> shapeMgu tm ((t1, t) : rest)
    (LazyType t _, _) -> shapeMgu tm ((t, t2) : rest)
    (_, LazyType t _) -> shapeMgu tm ((t1, t) : rest)
    (KindedType t _ _, _) -> shapeMgu tm ((t, t2) : rest)
    (_, KindedType t _ _) -> shapeMgu tm ((t1, t) : rest)
    (TypeName _ _ v1, _) -> if (v1 > 0) then
         case t2 of
         ProductType ts ps -> do 
             nts <- toPairState $ freshVarsT tm ts
             let s = Map.single v1 $ ProductType nts ps
             addSubst s
             shapeMgu tm (zip nts ts ++ subst s rest)
         FunType t3 ar t4 ps -> do
             v3 <- toPairState $ freshTypeVarT tm t3
             v4 <- toPairState $ freshTypeVarT tm t4
             let s = Map.single v1 $ FunType v3 ar v4 ps
             addSubst s
             shapeMgu tm ((t3, v3) : (v4, t4) : subst s rest)
         TypeAppl _ _ -> do 
             let (topTy, args) = getTypeAppl tm t2 
             vs <- toPairState $ freshVarsT tm args
             let s = Map.single v1 $ mkTypeAppl topTy vs
             addSubst s
             shapeMgu tm (zip vs args ++ subst s rest)
         _ -> error "shapeMgu"
         else error ("shapeMgu: " ++ showPretty t1 " < " ++ showPretty t2 "") 
    (_, TypeName _ _ _) -> do ats <- shapeMgu tm ((t2, t1) : map swap rest)
                              return $ map swap ats
    (TypeAppl t3 t4, TypeAppl t5 t6) ->
        shapeMgu tm ((t3, t5) : (t4, t6) : rest)
    (ProductType s1 _, ProductType s2 _) -> shapeMgu tm (zip s1 s2 ++ rest)
    (FunType t3 _ t4 _, FunType t5 _ t6 _) ->
        shapeMgu tm ((t5, t3) : (t4, t6) : rest)
    _ -> error "shapeMgu (invalid precondition)"

shapeUnify :: TypeMap -> [(Type, Type)] -> State Int (Subst, [(Type, Type)])
shapeUnify tm l = do 
    c <- get 
    let (as, (n, t)) = runState (shapeMgu tm l) (c, eps) 
    put n
    return (t, as)

-- must be integrated into shapeMgu
atomize :: TypeMap -> (Type, Type) -> [(Type, Type)]
atomize tm (t1, t2) = 
    case (t1, t2) of 
    (ExpandedType _ t, _) -> atomize tm (t, t2)
    (_, ExpandedType _ t) -> atomize tm (t1, t)
    (LazyType t _, _) -> atomize tm (t, t2)
    (_, LazyType t _) -> atomize tm (t1, t)
    (KindedType t _ _, _) -> atomize tm (t, t2)
    (_, KindedType t _ _) -> atomize tm (t1, t)
    (TypeName _ _ _, TypeName _ _ _) -> [(t1, t2)]
    _ -> 
       let (top1, as1) = getTypeAppl tm t1
           (top2, as2) = getTypeAppl tm t2
       in case (top1, top2) of 
          (TypeName _ k1 _, TypeName _ k2 _) -> 
              let r1 = rawKind k1 
                  r2 = rawKind k2 
                  (_, ks) = getRawKindAppl r1 as1 
              in if (r1 == r2 && length as1 == length as2) then
                 (top1, top2) : (concat $ zipWith ( \ k (a1, a2) -> 
                      let l1 = atomize tm (a1, a2)
                          l2 = atomize tm (a2, a1)
                      in case k of
                      ExtKind _ CoVar _ -> l1
                      ExtKind _ ContraVar _ -> l2
                      _ -> l1 ++ l2) ks $ zip as1 as2)
                 else error "atomize: getTypeAppl"
          _ -> error "atomize"

getRawKindAppl :: Kind -> [a] -> (Kind, [Kind])
getRawKindAppl k args = if null args then (k, []) else
    case k of 
    FunKind k1 k2 _ -> let (rk, ks) = getRawKindAppl k2 (tail args)
                       in (rk, k1 : ks)
    ExtKind ek _ _ -> getRawKindAppl ek args
    _ -> error ("getRawKindAppl " ++ show k)

-- input an atomized constraint list 
collapser :: TypeMap -> [(Type, Type)] -> Result Subst
collapser tm l = 
    let (_, t) = Rel.connComp $ foldr (uncurry Rel.insert) 
                 (fromTypeMap tm) l
        t2 = Map.map (Set.partition ( \ e -> case e of 
                                      TypeName _ _ n -> n==0
                                      _ -> error "collapser")) t
        ks = Map.elems t2
        ws = filter (\ p -> Set.size (fst p) > 1) ks
    in if null ws then
       return $ foldr ( \ (cs, vs) s -> 
               if Set.isEmpty cs then 
                    extendSubst s $ Set.deleteFindMin vs
               else extendSubst s (Set.findMin cs, vs)) eps ks
    else Result 
         (map ( \ (cs, _) -> 
                let (c1, rs) = Set.deleteFindMin cs
                    c2 = Set.findMin rs
                in Diag Hint ("contradicting type inclusions for '"
                         ++ showPretty c1 "' and '" 
                         ++ showPretty c2 "'") nullPos) ws) Nothing

extendSubst :: Subst -> (Type, Set.Set Type) -> Subst
extendSubst s (t, vs) = Set.fold ( \ (TypeName _ _ n) -> 
              Map.insert n t) s vs

-- | partition into qualification and subtyping constraints
partitionC :: Constraints -> (Constraints, Constraints)
partitionC = Set.partition ( \ c -> case c of
                             Kinding _ _ -> True
                             Subtyping _ _ -> False)

-- | convert subtypings constrains to a pair list
toListC :: Constraints -> [(Type, Type)]
toListC l = [ (t1, t2) | Subtyping t1 t2 <- Set.toList l ]

preClose :: TypeMap -> Constraints 
         -> State Int (Result (Subst, Constraints))
preClose tm cs = do 
    Result ds mr <- shapeRel tm cs 
    return $ Result ds $ case mr of 
        Nothing -> Nothing
        Just (s, qs, r) -> Just (s, foldr ( \ (a, b) -> 
                             insertC (Subtyping a b)) qs $ Rel.toList r) 

shapeRel :: TypeMap -> Constraints 
         -> State Int (Result (Subst, Constraints, Rel.Rel Type))
shapeRel tm cs = 
    let (qs, subS) = partitionC cs
        subL = toListC subS
    in case shapeMatch tm (map fst subL) $ map snd subL of
       Result ds Nothing -> return $ Result ds Nothing
       _ -> do (s1, atoms) <- shapeUnify tm subL
               case collapser tm atoms of
                   Result ds Nothing -> return $ Result ds Nothing
                   Result _ (Just s2) -> let s = compSubst s1 s2 in 
                     return $ return (s, substC s qs,
                       Rel.transReduce $ Rel.fromList $ subst s2 atoms)
                                                                
        
-- find monotonicity-based instantiations

monotonic :: TypeMap -> Int -> Type -> (Bool, Bool)
monotonic tm v t = 
     case t of 
	   TypeName _ _ i -> (True, i /= v)
	   ExpandedType _ t2 -> monotonic tm v t2
	   KindedType tk _ _ -> monotonic tm v tk
	   LazyType tl _ -> monotonic tm v tl
           _ -> let (top, args) = getTypeAppl tm t in case top of
                TypeName _ k _ -> 
                    let ks = snd $ getRawKindAppl (rawKind k) args 
                        (bs1, bs2) = unzip $ zipWith ( \ rk a ->
                             let (b1, b2) = monotonic tm v a
                             in case rk of
                                       ExtKind _ CoVar _ -> (b1, b2)
                                       ExtKind _ ContraVar _ -> (b2, b1)
                                       _ -> (b1 && b2, b1 && b2)) ks args
-- assume CoVar
                    in (and bs1, and bs2) 
                _ -> error "monotonic"

monoSubst :: TypeMap -> Rel.Rel Type -> Type -> Subst
monoSubst tm r t = 
    let varSet = Set.fromList . leaves (> 0)
        vs = Set.toList $ Set.unions $ map varSet $ Set.toList $ Rel.nodes r
        monos = filter ( \ (TypeArg n k _ _, i) -> case monotonic tm i t of
                                (True, _) -> 1 == Set.size 
                                    (Rel.predecessors r $ TypeName n k i)
                                _ -> False) vs
        antis = filter ( \ (TypeArg n k _ _, i) -> case monotonic tm i t of
                                (_, True) -> 1 == Set.size
                                     (Rel.succs r $ TypeName n k i)
                                _ -> False) vs
        rest = filter ( \ (TypeArg n k _ _, i) -> case monotonic tm i t of
                                (True, True) -> 1 /= Set.size
                                     (Rel.succs r $ TypeName n k i)
                                     && 1 /= Set.size
                                    (Rel.predecessors r $ TypeName n k i)
                                _ -> False) vs
    in if null monos then 
          if null antis then 
             if null rest then eps
             else let (TypeArg n k _ _, i) = head rest
                      tv = TypeName n k i 
                      s = Set.union (Rel.succs r tv)
                          $ Rel.predecessors r tv
                  in if Set.isEmpty s then eps 
                     else Map.single i $ Set.findMin s
          else let (TypeArg n k _ _, i) = head antis 
                   v = Set.findMin $ Rel.succs r $ TypeName n k i 
               in Map.single i v  
       else let (TypeArg n k _ _, i) = head monos 
                v = Set.findMin $ Rel.predecessors r $ TypeName n k i 
               in Map.single i v 

monoSubsts :: TypeMap -> Rel.Rel Type -> Type -> Subst
monoSubsts tm r t = 
    let s = monoSubst tm (Rel.transReduce $ Rel.irreflex r) t in
    if Map.isEmpty s then s else
       compSubst s $ 
            monoSubsts tm (Rel.transReduce $ Rel.irreflex $
                           Rel.image (subst s) r) 
                           $ subst s t 

close :: TypeMap -> Constraints -> Type
         -> State Int (Result (Subst, Constraints))
close tm cs t = do 
    Result ds mr <- shapeRel tm cs 
    return $ Result ds $ case mr of 
        Nothing -> Nothing
        Just (s1, qs, r) -> 
            let s2 = monoSubsts tm r t 
                s = compSubst s1 s2     
            in Just (s, foldr ( \ (a, b) -> 
                             insertC (Subtyping a b)) (substC s2 qs)
                              $ Rel.toList $ Rel.transReduce 
                              $ Rel.image (subst s) r) 

fromTypeMap :: TypeMap -> Rel.Rel Type
fromTypeMap = Map.foldWithKey (\ t ti r ->
                    foldr (Rel.insert (TypeName t (typeKind ti) 0)) r
                                  [ ty | ty@(TypeName _ _ _) <- 
                                    superTypes ti ]) Rel.empty 
 
