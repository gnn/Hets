{-|
Module       : $Header$
Copyright    : (c) Heng Jiang, Uni Bremen 2004
Licence      : similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer   : hets@tzi.de
Stability    : provisional
Portability  : non-portable

   Interface for web page with WASH/CGI

   todo:
     - default for checkbox regarding logging of input must be "selected" 
       .. done
     - temporary files should be created with these permissions:
        -rw-rw-r-- (than every member of grp agcofi can remove 
		    temporary files)
       .. done
     - LaTeX code should only be available as download  .. done
     - ASCII code should also be available as download  .. done
     - additionally to (show random) the temporary file names 
       should contain a fraction of the seconds since epoch and/or
       the ProcessID
       .. done
     - english sentences in the output need corrections
       .. done
     - when the HTML-PrettyPrinting is available: generated HTML-Code 
       instead of poorly rendered ASCII has to be inserted as response
       .. ???
     - a handler for warning message
-}
module Main where

import CGI
import Options
import WriteFn
import ReadFn
import Common.Lib.Map as Map
import Common.Result
import Common.AS_Annotation
import Static.AnalysisLibrary
import Comorphisms.LogicGraph
import Static.DevGraph
import Syntax.AS_Library
import Syntax.Parse_AS_Structured
import Maybe
import Random
import IO
import Time
import System.Cmd
import System.Posix.IO
import System.Posix.Types
import System.Posix.Files
import System.Posix.Process
import System.Posix.Env
import Version

type DiagStr = String
type HtmlTitle = String
type ResAna  = String
type SelectedBox = (Bool, Bool, Bool, Bool)

main :: IO()
main =
    run mainCGI

mainCGI :: CGI()
mainCGI =
    do 
       ask $ html (do CGI.head (title $ text "Hets Web Interface")
	       	      CGI.body $ makeForm $ page1 ("Hets " ++ hetcats_version)) 

page1 :: String -> WithHTML x CGI ()
page1 title1 =
    do    
      h1 $ text title1
      p (text "Enter a CASL 1.0.1 specification or library in the input zone, then press SUBMIT:")
      -- Input field
      input   <- p (makeTextarea "" (attr "rows" "22" ## attr "cols" "68"))
      -- check box
      selectEnv <- checkboxInputField (attr "valus" "yes")
      text "output pretty print ASCII"
      selectTex <- checkboxInputField (attr "valus" "yes")
      text "output pretty print LaTeX"
      selectTree <- checkboxInputField (attr "valus" "yes")
      text "output parse tree"
      selectAchiv <- p $ b ( checkboxInputField(attr "checked" "checked") ##
			 text "If this checkbox is selected, your input will be logged!")
      -- submit/reset botton
      p (submit (F5 input selectTree selectEnv selectTex selectAchiv)
	         handle (fieldVALUE "Submit") >>
	 submit0 reset (fieldVALUE "reset"))
      hr_S $ CGI.empty
      p $ (do text "Contact address: "
	      hlink (read "mailto:cofi@informatik.uni-bremen.de") $ 
	             text "cofi@informatik.uni-bremen.de")

reset :: CGI()
reset = mainCGI

-- handle of the submit botton
handle (F5 input box1 box2 box3 box4) = 
    let str  = value input
	tree = value box1
	env  = value box2
	tex  = value box3
	achiv= value box4 
    in  do
	random1 <- io $ getRandom
	processID <- io $ getProcessID
	let outputfile = "/home/www/cofi/hets-tmp/result" ++ (show processID) ++
			    (show random1)
	res <- io $ anaInput str (tree, env, tex, achiv) outputfile
	ask $ html ( do CGI.head (title $ text "HETS results")
			CGI.body $ printR str res (tree, env, tex, achiv) outputfile)
    where
      getRandom :: IO Int
      getRandom = getStdRandom (randomR (100000,999999))

-- Analyze the input
anaInput :: String -> SelectedBox -> FilePath -> IO([DiagStr],[(HtmlTitle, ResAna)])
anaInput contents showS@(_,_,_,willAchiv) outputfiles =
   do 
   setEnv "HETS_LIB" "/home/cofi/CASL-lib" True
   (parseErrors, ast) <- read_LIB_DEFN_M_WI defaultLogic "<stdin>" contents
   if parseErrors == "" then 
      do
      Common.Result.Result ds res <- ioresToIO 
				     (ana_LIB_DEFN logicGraph defaultLogic 
				      defaultHetcatsOpts{outputToStdout = False} emptyLibEnv ast)
      let diagStrs1  = Prelude.map show ds
          diagStrs2  = reverse $ filterDiagStr [] diagStrs1
      -- putStrLn $ show $ length $ lines $ Prelude.head diagStrs1
      case res of
	       Just (_, libdefn1, _, _) ->  
		   do
		   let Lib_defn _ alibItems _ _ = libdefn1
		       items = reverse $ Prelude.map item alibItems
		   -- diagStrs' <- addSpnToDiags items diagStrs
		   if hasErrors ds then
		      return (diagStrs2, [])
		      else do
			   saveLog willAchiv contents
			   anaInput_aux diagStrs2 res outputfiles showS
	       Nothing -> return(diagStrs2,[])
      else return (parseErrors:[], [])

   where 
      filterDiagStr :: [String] -> [DiagStr] -> [DiagStr]
      filterDiagStr str [] = str
      filterDiagStr str d@(hdiags:rdiags)
	| (length $ lines hdiags) < 2 = 
	        if "*** Hint" == take 8 hdiags then  filterDiagStr str rdiags
		   else if "*** FatalError" == take 14 hdiags then hdiags:str
			   else if "*** MessageW ," == take 14 hdiags then
			           filterDiagStr ((drop 14 hdiags):str) rdiags
			           else filterDiagStr (hdiags:str) rdiags
        | otherwise  = filterDiagStr (filterDiagStr' str $ lines hdiags) rdiags 

      filterDiagStr' :: [String] -> [DiagStr] -> [DiagStr]
      filterDiagStr' str' [] = str'
      filterDiagStr' str' (hd:rd)
	  | "*** Hint"       == take 8 hd = filterDiagStr' str' rd
	  | "*** MessageW ," == take 14 hd = filterDiagStr' ((drop 14 hd):str') rd
	  | otherwise = filterDiagStr' (hd:str') rd
		    
      anaInput_aux :: [DiagStr]
		      -> Maybe(LIB_NAME, LIB_DEFN, DGraph, LibEnv)
		      -> FilePath
                      -> SelectedBox 
		      -> IO([DiagStr],[(HtmlTitle, ResAna)])
      anaInput_aux diags1 res outputfiles1 (showTree, showEnv, showTex, _) =
	  case res of 
	       Just (libName, libDefn, _, libEnv) ->
	        do 
		 let (globalAnnos, _, _) =  fromJust $ Map.lookup libName libEnv
		     fileMode = foldl unionFileModes nullFileMode 
				[ownerReadMode, ownerWriteMode, groupReadMode, groupWriteMode, otherReadMode]
		 resAsc <- write_casl_asc_stdout defaultHetcatsOpts globalAnnos libDefn
		 resTex <- write_casl_latex_stdout defaultHetcatsOpts globalAnnos libDefn
		 if showTex then
		    do
		    let pptexFile = outputfiles1 ++ ".pp.tex"
			latexFile = outputfiles1 ++ ".tex"
			pdfFile   = outputfiles1 ++ ".pdf"
			tmpFile   = outputfiles1 ++ ".tmp"
		    write_casl_latex defaultHetcatsOpts globalAnnos (pptexFile) libDefn
		    rawSystem "cp" ["/home/www/cofi/hets-tmp/mould.m", latexFile]
		    setFileMode pptexFile fileMode
		    setFileMode latexFile fileMode
		    appendFile latexFile ("\\input{"++ pptexFile ++"}\n" ++ "\\end{document}\n")
                    
                    system ("/usr/local/share/teTeX/2.0/bin/ix86-linux2/pdflatex " ++
			   latexFile ++ " > " ++ tmpFile)
                    system "mv result* /home/www/cofi/hets-tmp/"
		    setFileMode pdfFile fileMode
		    return()
			       
		    else return()
		 if showEnv then
		    do
		    let txtFile = outputfiles1 ++ ".txt"
		    write_casl_asc defaultHetcatsOpts globalAnnos txtFile libDefn
		    setFileMode txtFile fileMode
		    else return()
		 return $ (diags1, selectOut [showEnv, showTex, showTree] libDefn resAsc resTex)
	       Nothing -> return ([],[])

      selectOut :: [Bool] -> LIB_DEFN -> String -> String -> [(HtmlTitle, ResAna)]
      selectOut [] _ _ _ = []
      selectOut (hb:rb) libDefn ra rt 
		| length rb == 2 && hb = 
		    ("ASCII code:", ra):(selectOut rb libDefn ra rt)
		| length rb == 1 && hb = 
		    ("LaTeX code:", ""):(selectOut rb libDefn ra rt)
		    -- ("LaTeX code:", rt):(selectOut rb libDefn ra rt)
		| length rb == 0 && hb = 
		    ("Parse tree:", show libDefn):(selectOut rb libDefn ra rt)
		| otherwise = selectOut rb libDefn ra rt
      -- log file
      saveLog :: Bool -> String -> IO()
      saveLog willSave contents 
	| willSave =
	          do 
		  let logFile = "/home/www/cofi/hets-tmp/hets.log"
		  fd <- openFd logFile ReadWrite Nothing defaultFileFlags{append = True} 
		  fileSize <- sizeof fd
		  let filelock = (WriteLock, AbsoluteSeek, 0, fileSize)  
		      fileunlock = (Unlock, AbsoluteSeek, 0, fileSize)
		  aktTime <- timeStamp 
		  setLock fd filelock
		  fdWrite fd (aktTime ++ "\n" ++ contents ++ "\n\n")  
  		  setLock fd fileunlock
		  closeFd fd
	| otherwise = return ()
        where 
          timeStamp :: IO String
          timeStamp =  do t <- getClockTime		      
	 		  ct <- toCalendarTime t
			  return $ calendarTimeToString ct

          sizeof :: Fd -> IO FileOffset
	  sizeof fd = do fstatus <- getFdStatus fd
			 return $ fileSize fstatus
      
-- Print the result		    
printR :: String -> ([DiagStr], [(HtmlTitle, ResAna)]) -> SelectedBox -> FilePath 
          -> WithHTML x CGI ()
printR str (diags2, result) selectedBoxes outputFiles =
    do 
       h1 $ text "You have submitted the HetCASL library:"
       mapM_ (\l -> text l >> br CGI.empty) $ lines str
       h1 $ text "Result of parsing and static checking:"
       mapM_ (\l -> h3 $ text l >> br CGI.empty) $ diags2 
       printRes selectedBoxes outputFiles result 
       hr_S $ CGI.empty
       p (do text "Not the result you expected ? Please check the "
	     hlink (read "http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/UserGuide.pdf") $ text "Hets Manual"
	     text "."
	 )
       hr_S $ CGI.empty
       p $ (do text "Contact address: "
	       hlink (read "mailto:cofi@informatik.uni-bremen.de") $
		      text "cofi@informatik.uni-bremen.de"
	   )
    where 
        printRes :: SelectedBox -> FilePath -> 
		    [(DiagStr, ResAna)] -> WithHTML x CGI ()
	printRes _ _ [] = CGI.empty
	printRes (isTree, isEnv, isTex, willAchiv) outputfiles 
		     ((title_ana, text_ana):rR) =
          do h3 $ text title_ana
       	     p $ mapM_ (\l -> text l >> br CGI.empty) $ lines text_ana
	     if isEnv then
		do  
		p $ i(do text "You can download the " 
		         hlink (read ("http://www.informatik.uni-bremen.de/cofi/hets-tmp/" ++
				      (drop 24 (outputfiles++".txt")))) $ text "ACSII file" 
		         text " here. The file will be deleted after 30 minutes.\n" 
		     )
		printRes (isTree, False, isTex, willAchiv) outputfiles rR
		else if isTex then
		     do
		     p $ i(do text "You can download the "
			      hlink (read ("http://www.informatik.uni-bremen.de/cofi/hets-tmp/" ++
					   (drop 24 (outputfiles++".pp.tex")))) $ text "LaTeX file" 
			      text " here. For compiling the LaTeX output, you need " 
			      hlink (read "http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/hetcasl.sty") $ text "hetcasl.sty" 
			      text "."
			  )
		     p $ i(do text "You can also download the " 
			      hlink (read ("http://www.informatik.uni-bremen.de/cofi/hets-tmp/" ++
					   (drop 24 (outputfiles++".pdf")))) $ text "PDF file" 
			      text ". All files will be deleted after 30 minutes.\n" 
			  )
		     printRes (isTree, isEnv, False, willAchiv) outputfiles rR
		     else if isTree then
			  printRes (False, isEnv, isTex, willAchiv) outputfiles rR
			  else printRes (isTree, isEnv, isTex, willAchiv) outputfiles rR
