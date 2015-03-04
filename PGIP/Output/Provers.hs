{-# LANGUAGE CPP, TypeFamilies, DeriveDataTypeable #-}

module PGIP.Output.Provers
  ( formatProvers
  ) where

import PGIP.Output.Formatting
import PGIP.Output.Mime

import PGIP.Query (ProverMode (..))

import Logic.Comorphism (AnyComorphism)

import Common.Json (ppJson, asJson)
import Common.ToXml (asXml)

import Text.XML.Light (ppTopElement)

import Data.Data

type ProversFormatter = ProverMode ->
                        [(AnyComorphism, [String])] -> (String, String)

formatProvers :: Maybe String -> ProversFormatter
formatProvers format proverMode availableProvers = case format of
  Just "json" -> formatAsJSON
  _ -> formatAsXML
  where
  computedProvers :: Provers
  computedProvers =
    let proverNames = showProversOnly availableProvers in
    case proverMode of
      GlProofs -> emptyProvers { provers = Just proverNames }
      GlConsistency -> emptyProvers { consistencyCheckers = Just proverNames }

  formatAsJSON :: (String, String)
  formatAsJSON = (jsonC, ppJson $ asJson computedProvers)

  formatAsXML :: (String, String)
  formatAsXML = (xmlC, ppTopElement $ asXml computedProvers)

data Provers = Provers
  { provers :: Maybe [String]
  , consistencyCheckers :: Maybe [String]
  } deriving (Show, Typeable, Data)

emptyProvers :: Provers
emptyProvers = Provers { provers = Nothing, consistencyCheckers = Nothing }
