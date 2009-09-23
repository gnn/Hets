{- |
Module      :  $Header$
Description :  the proof status with manipulating functions
Copyright   :  (c) Jorina F. Gerken, Till Mossakowski, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  ken@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable(Logic)

the proof status with manipulating functions
-}

module Proofs.StatusUtils
    ( lookupHistory
    , removeContraryChanges
    , isIdentityEdge
    ) where

import Static.DevGraph
import Data.Graph.Inductive.Graph
import Common.LibName
import Logic.Logic

{-
   proof status = (DG0,[(R1,DG1),...,(Rn,DGn)])
   DG0 is the development graph resulting from the static analysis
   Ri is a list of rules that transforms DGi-1 to DGi
   With the list of intermediate proof states, one can easily implement
    an undo operation
-}

-- -------------------------------
-- methods used in several proofs
-- -------------------------------

{- returns the history that belongs to the given library name-}
lookupHistory :: LibName -> LibEnv -> ProofHistory
lookupHistory ln = proofHistory . lookupDGraph ln

-- ----------------------------------------------
-- methods that keep the change list clean
-- ----------------------------------------------

{- | remove the contray changes out of the list if it's necessary,
     so that the list can stay clean.
-}
removeContraryChanges :: [DGChange] -> [DGChange]
removeContraryChanges [] = []
removeContraryChanges (change : changes) =
  case contraryChange of
    Just c -> removeContraryChanges (removeChange c changes)
    Nothing -> change : removeContraryChanges changes
  where
    contraryChange =
      case getContraryChange change of
        Just c -> if c  `elem` changes then Just c else Nothing
        Nothing -> Nothing

{- | get the contrary change to the given one, but only Insertion is
     interesting.
-}
getContraryChange :: DGChange -> Maybe DGChange
getContraryChange change = case change of
    InsertEdge edge -> Just $ DeleteEdge edge
    -- re-insertion of deleted edge may be useful if node has changed
    InsertNode node -> Just $ DeleteNode node
    -- re-insertion of deleted node may be useful if node has changed
    -- ... although this should be recognized ... a bit strange ...
    DeleteEdge _ -> Nothing
    DeleteNode _ -> Nothing -- Just $ InsertNode node
    SetNodeLab _ _ -> Nothing

{- | remove the unnecessary changes out of the list.
-}
removeChange :: DGChange -> [DGChange] -> [DGChange]
removeChange _ [] = []
removeChange c1 (c2:rest) | c1==c2 = rest
-- when a node is removed afterwards, throw away all edge operations
-- refering to that node that are encountered on the way
removeChange c1@(DeleteNode (n,_)) (c2:rest) =
  if case c2 of
     InsertEdge (n1,n2,_) -> n==n1 || n==n2
     DeleteEdge (n1,n2,_) -> n==n1 || n==n2
     SetNodeLab _ (m, _) -> n == m
     _ -> False
   then removeChange c1 rest
   else c2:removeChange c1 rest
removeChange c1 (c2:rest) = c2:removeChange c1 rest

{- | check if the given edge is an identity edge, namely a loop
     from a node to itself with an identity morphism. -}
isIdentityEdge :: LEdge DGLinkLab -> LibEnv -> DGraph -> Bool
isIdentityEdge (src, tgt, edgeLab) ps dgraph =
  let nodeLab = labDG dgraph src
      gsig = dgn_sign nodeLab
      res = src == tgt &&
        dgl_morphism edgeLab == ide gsig
  in if isDGRef nodeLab then -- just a consistency check
    let dg = lookupDGraph (dgn_libname nodeLab) ps
        gsig2 = dgn_sign $ labDG dg $ dgn_node nodeLab
    in if gsig2 == gsig then res else error "isIdentityEdge"
  else res
