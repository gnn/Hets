
{- HetCATS/CASL/SortItem.hs
   $Id$
   Authors: Christian Maeder
   Year:    2002
   
   parse SORT-ITEM and "sort/sorts SORT-ITEM ; ... ; SORT-ITEM"
   parse DATATYPE-DECL

   http://www.cofi.info/Documents/CASL/Summary/
   from 25 March 2001

   C.2.1 Basic Specifications with Subsorts
-}

module CASL.SortItem (sortItem, datatype) where

import Common.AnnoState
import Common.Id
import Common.Keywords
import Common.Lexer
import CASL.AS_Basic_CASL
import Common.AS_Annotation
import Common.Lib.Parsec
import Common.Token
import CASL.Formula

-- ------------------------------------------------------------------------
-- sortItem
-- ------------------------------------------------------------------------

commaSortDecl :: Id -> AParser SORT_ITEM
commaSortDecl s = do c <- anComma
		     (is, cs) <- sortId `separatedBy` anComma
		     let l = s : is 
		         p = map tokPos (c:cs) in
		       subSortDecl (l, p) <|> return (Sort_decl l p)

isoDecl :: Id -> AParser SORT_ITEM
isoDecl s = do e <- equalT
               subSortDefn (s, tokPos e)
		 <|>
		 (do (l, p) <- sortId `separatedBy` equalT
		     return (Iso_decl (s:l) (map tokPos (e:p))))

subSortDefn :: (Id, Pos) -> AParser SORT_ITEM
subSortDefn (s, e) = do a <- annos
			o <- oBraceT
			v <- varId
			c <- colonT
			t <- sortId
			d <- dotT -- or bar
			f <- formula
			p <- cBraceT
			return $ Subsort_defn s v t (Annoted f [] a []) 
				(e: map tokPos [o, c, d, p])

subSortDecl :: ([Id], [Pos]) -> AParser SORT_ITEM
subSortDecl (l, p) = do t <- lessT
			s <- sortId
			return (Subsort_decl l s (p++[tokPos t]))

sortItem :: AParser SORT_ITEM 
sortItem = do s <- sortId ;
	      subSortDecl ([s],[])
		    <|>
		    commaSortDecl s
		    <|>
                    isoDecl s
		    <|> 
		    return (Sort_decl [s] [])

-- ------------------------------------------------------------------------
-- typeItem
-- ------------------------------------------------------------------------

datatype :: AParser DATATYPE_DECL
datatype = do s <- sortId
	      addAnnos
	      e <- asKey defnS
	      addAnnos
	      a <- getAnnos
	      (Annoted v _ _ b:as, ps) <- aAlternative 
		`separatedBy` barT
	      return (Datatype_decl s (Annoted v [] a b:as) 
			(map tokPos (e:ps)))

aAlternative :: AParser (Annoted ALTERNATIVE)
aAlternative = do a <- alternative 
		  an <- annos
		  return (Annoted a [] [] an)

alternative :: AParser ALTERNATIVE
alternative = do s <- pluralKeyword sortS
		 (ts, cs) <- sortId `separatedBy` anComma
		 return (Subsorts ts (map tokPos (s:cs)))
              <|> 
              do i <- parseId
		 do o <- oParenT
		    (cs, ps) <- component `separatedBy` anSemi
		    c <- cParenT
		    let qs = toPos o ps c in
			do q <- quMarkT
			   return (Partial_construct i cs 
				     (qs++[tokPos q]))
			<|> return (Total_construct i cs qs)

		   <|> return (Total_construct i [] [])

isSortId :: Id -> Bool
isSortId (Id is _ _) = length is == 1 && not (null (tokStr (head is))) 
		       && head (tokStr (head is)) `elem` caslLetters

component :: AParser COMPONENTS
component = do (is, cs) <- parseId `separatedBy` anComma
	       if length is == 1 && isSortId (head is) then
		 compSort is cs 
		 <|> return (Sort (head is))
		 else compSort is cs

compSort :: [OP_NAME] -> [Token] -> AParser COMPONENTS
compSort is cs = do c <- colonST
		    (b, t, _) <- opSort
		    let p = map tokPos (cs++[c]) in 
		      return (if b then Partial_select is t p
			      else  Total_select is t p)
