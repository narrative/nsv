{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable, TypeFamilies, TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}

module Database where

import           Control.Concurrent
import           Control.Lens
import           Control.Monad.Reader
import           Control.Monad.State
import           Data.Acid
import           Data.Aeson.Lens (key, members, values)
import           Data.SafeCopy
import qualified Data.Text.Lazy as T
import           Data.Typeable
import qualified Network.Wreq as W
import           System.Random

type Database = ReaderT (AcidState Posts) IO

data Entry = Entry {title :: T.Text, author :: T.Text}
  deriving (Show, Typeable)

data Posts = Posts [Entry]
  deriving (Show, Typeable)

$(deriveSafeCopy 0 'base ''Entry)
$(deriveSafeCopy 0 'base ''Posts)

addEntry :: Entry -> Update Posts ()
addEntry e = do
  Posts entries <- get
  put (Posts $ e:entries)

clearEntries :: Update Posts ()
clearEntries = put $ Posts []

getEntries :: Query Posts [Entry]
getEntries = do
  Posts t <- ask
  return t

$(makeAcidic ''Posts ['addEntry, 'clearEntries, 'getEntries])

initDB :: IO (AcidState Posts)
initDB = openLocalState (Posts [])

queryState :: Database (EventResult GetEntries)
queryState = do
 db <- ask
 liftIO (query db GetEntries)

updateState :: T.Text -> T.Text -> Database ()
updateState t a = do
  db <- ask
  liftIO (update db $ AddEntry $ Entry t a)

manageDatabase :: Database ()
manageDatabase = forever $ do
  res <- queryState
  liftIO . print $ res
  liftIO . threadDelay $ 10000000

--requestData :: IO (Response ByteString)
requestData = do
  r <- W.get "http://reddit.com/r/quotes.json"
  let test = r ^? W.responseBody . key "data" . key "children"
  print test


readRandom :: Database (Maybe Entry)
readRandom = do
  entries <- queryState
  case entries of
    [] -> lift $ return Nothing
    xs -> liftIO $ (Just . (xs !!)) <$> randomRIO (0, (length xs) - 1)
