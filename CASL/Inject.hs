{- |
Module      :  $Header$
Description :  Replace Sorted_term(s) with explicit injection functions.
Copyright   :  (c) Christian Maeder, Uni Bremen 2005
License     :  GPLv2 or higher

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

Replace Sorted_term(s) with explicit injection functions.  Don't do this after
   simplification since crucial sort information may be missing
 -}

module CASL.Inject where

import CASL.AS_Basic_CASL
import CASL.Sign
import CASL.Fold
import Common.Id

makeInjOrProj :: (OP_TYPE -> Id) -> OpKind -> Range -> TERM f -> SORT
              -> TERM f
makeInjOrProj mkName fk pos argument to =
    let from = sortOfTerm argument
        t = Op_type fk [from] to pos
    in if to == from then argument else
    Application (Qual_op_name (mkName t) t pos) [argument] pos

injectUnique :: Range -> TERM f -> SORT -> TERM f
injectUnique = makeInjOrProj uniqueInjName Total

uniqueInjName :: OP_TYPE -> Id
uniqueInjName t = case t of
    Op_type _ [from] to _ -> mkUniqueInjName from to
    _ -> error "CASL.Inject.uniqueInjName"

injRecord :: (f -> f) -> Record f (FORMULA f) (TERM f)
injRecord mf = (mapRecord mf)
     { foldApplication = \ _ o ts ps -> case o of
         Qual_op_name _ ty _ -> Application o
             (zipWith (injectUnique ps) ts $ args_OP_TYPE ty) ps
         _ -> error "injApplication"
     , foldSorted_term = \ _ st s ps -> injectUnique ps st s
     , foldPredication = \ _ p ts ps -> case p of
         Qual_pred_name _ (Pred_type s _) _ -> Predication p
             (zipWith (injectUnique ps) ts s) ps
         _ -> error "injPredication" }

injTerm :: (f -> f) -> TERM f -> TERM f
injTerm = foldTerm . injRecord

injFormula :: (f -> f) -> FORMULA f -> FORMULA f
injFormula = foldFormula . injRecord

-- | takes a list of OP_SYMB generated by
-- 'CASL.AS_Basic_CASL.recover_Sort_gen_ax' and inserts these operations into
-- the signature; unqualified OP_SYMBs yield an error
insertInjOps :: Sign f e -> [OP_SYMB] -> Sign f e
insertInjOps = foldl insOp
    where insOp sign o =
              case o of
              (Qual_op_name i ot _)
                  | isInjName i ->
                       sign { opMap = addOpTo i (toOpType ot) (opMap sign)}
                  | otherwise -> sign
              _ -> error "CASL.Inject.insertInjOps: Wrong constructor."
