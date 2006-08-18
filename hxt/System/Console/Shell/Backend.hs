{-
 - 
 -  Copyright 2005-2006, Robert Dockins.
 -  
 -}

{- | This module defines the Shellac interface for shell backends.  A shell backend
     is required to provide sensible implementations for 'flushOutput',
     'getSingleChar', 'getInput', and 'getWordBreakChars'.  All other operations may 
     be noops (however, they must not denote bottom!).  
-}

module System.Console.Shell.Backend where


-- | The type of completion functions.  The argument is a triple
--   consisting of (before,word,after), where \'word\' is a string
--   of non-word-break characters which contains the cursor position.
--   \'before\' is all characters on the line before \'word\' and \'after\'
--   is all characters on the line after word.  The return value should
--   be \'Nothing\' if no completions can be generated, or
--   \'Just (newWord,completions)\' if completions can be generated.  \'newWord\'
--   is a new string to replace \'word\' on the command line and \'completions\'
--   is a list of all possible completions of \'word\'.  To achieve the standard
--   \"complete-as-far-as-possible\" behavior, \'newWord\' should be the longest possible
--   prefix of all words in \'completions\'.

type CompletionFunction = (String,String,String) 
                        -> IO (Maybe (String, [String]))

-- | A datatype representing ouput to be printed.  The different categories of
--   output are distinguished to that shell backends can, for example, apply
--   different colors or send output to different places (stderr versus stdout).

data BackendOutput
   = RegularOutput String      -- ^ The most regular way to produce output
   | InfoOutput String         -- ^ An informative output string, such as command help
   | ErrorOutput String        -- ^ An string generated by an error


data ShellBackend bst
   = ShBackend
     { initBackend                    :: IO bst
         -- ^ Provides the backend a way to perform any necessary initilization
	 --   before the shell starts.  This function is called once for each
         --   shell instance.  The generated value will be passed back in to each call of the
         --   other methods in this record.

     , outputString                   :: bst -> BackendOutput -> IO ()
         -- ^ Causes the string to be sent to the underlying console device.

     , flushOutput                    :: bst -> IO ()
         -- ^ Perform any operations necessary to clear any output buffers.  After this
         --   operation, the user should be able to view any output sent to this backend.

     , getSingleChar                  :: bst -> String -> IO (Maybe Char)
         -- ^ Retrive a single character from the user without waiting for carriage return.

     , getInput                       :: bst -> String -> IO (Maybe String)
         -- ^ Print the prompt and retrive a line of input from the user.

     , addHistory                     :: bst -> String -> IO ()
         -- ^ Add a string to the history list.

     , setWordBreakChars              :: bst -> String -> IO ()
         -- ^ Set the characters which define word boundaries.  This is mostly used
         --   for defining where completions occur.

     , getWordBreakChars              :: bst -> IO String
         -- ^ Get the current set of word break characters.

     , onCancel                       :: bst -> IO ()
         -- ^ A callback to run whenever evaluation or a command is cancled
         --   by the keyboard signal

     , setAttemptedCompletionFunction :: bst -> CompletionFunction -> IO ()
         -- ^ A completion function that is tried first.

     , setDefaultCompletionFunction   :: bst -> Maybe (String -> IO [String]) -> IO ()
         -- ^ An alternate function to generate completions.  The function given takes the
         --   word as an argument and generates all possible completions.  This function is called
         --   (if set) after the attemptedCompletionFunction if it returns \'Nothing\'.

     , completeFilename               :: bst -> String -> IO [String]
         -- ^ A backend-provided method to complete filenames.

     , completeUsername               :: bst -> String -> IO [String]
         -- ^ A backend-provided method to complete usernames.

     , clearHistoryState              :: bst -> IO ()
         -- ^ An operation to clear the history buffer.

     , setMaxHistoryEntries           :: bst -> Int -> IO ()
         -- ^ Sets the maximum number of entries managed by the history buffer.

     , getMaxHistoryEntries           :: bst -> IO Int
         -- ^ Gets the maximum number of entries managed by the history buffer.

     , readHistory                    :: bst -> FilePath -> IO ()
         -- ^ Read the history buffer from a file.  The file should be formatted
         --   as plain-text, with each line in the file representing a single command
         --   entered, most recent commands at the bottom. (This format is what readline
         --   produces)

     , writeHistory                   :: bst -> FilePath -> IO ()
         -- ^ Write the history buffer to a file.  The file should be formatted in the
         --   same way as in the description for 'readHistory'.
     }
