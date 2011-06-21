{- |
Module      :  $Header$
Copyright   :  Heng Jiang, Uni Bremen 2007
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

Signatures and sentences for OWL 2
-}

module OWL2.Sign where

import OWL2.AS
import qualified Data.Set as Set
import qualified Data.Map as Map
import Common.DocUtils

type ID = IRIreference          -- for universal ID
type OntologyID = IRIreference
type ClassID = IRIreference
type DatatypeID = IRIreference
type IndividualID = IRIreference
type DataRoleIRI = IRIreference
type IndividualRoleIRI = IRIreference
type AnnotationPropertyID = IRIreference

instance Pretty Sign

data Sign = Sign
            { concepts :: Set.Set ClassID
              -- ^ a set of classes
            , datatypes :: Set.Set DatatypeID -- ^ a set of datatypes
            , objectProperties :: Set.Set IndividualRoleIRI
              -- ^ a set of object properties
            , dataProperties :: Set.Set DataRoleIRI
              -- ^ a set of data properties
            , annotationRoles :: Set.Set AnnotationPropertyID
            , individuals :: Set.Set IndividualID  -- ^ a set of individual
              -- ^ a set of axioms of subconceptrelations, domain an drenge
              -- ^of roles, functional roles and concept membership
            , prefixMap :: PrefixMap 
            } deriving (Show, Eq, Ord)

data SignAxiom =
    Subconcept ClassExpression ClassExpression   -- subclass, superclass
  | Role (DomainOrRangeOrFunc (RoleKind, RoleType)) ObjectPropertyExpression
  | Data (DomainOrRangeOrFunc ()) DataPropertyExpression
  | Conceptmembership IndividualID ClassExpression
    deriving (Show, Eq, Ord)

data RoleKind = FuncRole | RefRole deriving (Show, Eq, Ord)

data RoleType = IRole | DRole deriving (Show, Eq, Ord)

data DesKind = RDomain | DDomain | RIRange deriving (Show, Eq, Ord)

data DomainOrRangeOrFunc a =
    DomainOrRange DesKind ClassExpression
  | RDRange DataRange
  | FuncProp a
    deriving (Show, Eq, Ord)

emptySign :: Sign
emptySign = Sign
  { concepts = Set.empty
  , datatypes = Set.empty
  , objectProperties = Set.empty
  , dataProperties = Set.empty
  , annotationRoles = Set.empty
  , individuals = Set.empty
  , prefixMap = Map.empty
  }

-- ignoe ontologyID
diffSig :: Sign -> Sign -> Sign
diffSig a b =
    a { concepts = concepts a `Set.difference` concepts b
      , datatypes = datatypes a `Set.difference` datatypes b
      , objectProperties = objectProperties a `Set.difference` objectProperties b
      , dataProperties = dataProperties a `Set.difference` dataProperties b
      , annotationRoles = annotationRoles a `Set.difference` annotationRoles b
      , individuals = individuals a `Set.difference` individuals b
      }

addSign :: Sign -> Sign -> Sign
addSign toIns totalSign =
    totalSign { 
                concepts = Set.union (concepts totalSign)
                                     (concepts toIns),
                datatypes = Set.union (datatypes totalSign)
                                      (datatypes toIns),
                objectProperties = Set.union (objectProperties totalSign)
                                           (objectProperties toIns),
                dataProperties = Set.union (dataProperties totalSign)
                                            (dataProperties toIns),
                annotationRoles = Set.union (annotationRoles totalSign)
                                            (annotationRoles toIns),
                individuals = Set.union (individuals totalSign)
                                        (individuals toIns)
              }

isSubSign :: Sign -> Sign -> Bool
isSubSign a b =
    Set.isSubsetOf (concepts a) (concepts b)
       && Set.isSubsetOf (datatypes a) (datatypes b)
       && Set.isSubsetOf (objectProperties a) (objectProperties b)
       && Set.isSubsetOf (dataProperties a) (dataProperties b)
       && Set.isSubsetOf (annotationRoles a) (annotationRoles b)
       && Set.isSubsetOf (individuals a) (individuals b)

symOf :: Sign -> Set.Set Entity
symOf s = Set.unions
  [ Set.map (Entity Class) $ concepts s
  , Set.map (Entity Datatype) $ datatypes s
  , Set.map (Entity ObjectProperty) $ objectProperties s
  , Set.map (Entity DataProperty) $ dataProperties s
  , Set.map (Entity NamedIndividual) $ individuals s ]
