{-# LANGUAGE
    DeriveDataTypeable
  , FlexibleInstances
  , LambdaCase
  , MultiParamTypeClasses
  , NoImplicitPrelude
  , NoMonomorphismRestriction
  , TemplateHaskell
  , TypeFamilies
  , UndecidableInstances
  #-}
module Example where

-- Per convention we use 'id' and '(.)' 'from Control.Category' If you
-- don't want this, use 'returnA' and '<<<' respectively instead.

import Prelude.Compat hiding (id, (.))

import Control.Arrow
import Control.Category
import Data.UUID

import Silk.Opaleye
import Silk.Opaleye.TH

-- | We use a newtype to reperesent a foreign key
newtype Id = Id { unId :: UUID }
  deriving (Show, Typeable)

-- | This generates a number of top level declarations for our type:
--
-- > unsafeId :: UUID -> Id
-- > unsafeId' :: UUID -> Maybe Id
-- > instance Fromfield Id
-- > instance ShowConstant Id
-- > instance PGRep Id ~ a => QueryRunnerColumnDefault Id Id
-- > instance Conv Id
--
mkId ''Id

data Gender = Male | Female
  deriving (Show, Typeable)

genderToString :: Gender -> String
genderToString = \case
  Male   -> "male"
  Female -> "female"

stringToGender :: String -> Maybe Gender
stringToGender = \case
  "male"   -> Just Male
  "female" -> Just Female
  _        -> Nothing

makeColumnInstances ''Gender ''String 'genderToString 'stringToGender

makeTypes [d|
    data Person = Person
      { id'    :: Id
      , name   :: String
      , age    :: Int
      , gender :: Nullable Gender
      } deriving Show
  |]

makeAdaptorAndInstance "pPerson" ''PersonP

makeTable "people" 'pPerson ''PersonP

queryAll :: Query (To Column Person)
queryAll = queryTable table

byId :: UUID -> Query (To Column Person)
byId i = where_ (\u -> id' u .== constant (Id i)) . queryAll

nameOrder :: Order (To Column Person)
nameOrder = asc (lower . arr name)

allByName :: Query (To Column Person)
allByName = orderBy nameOrder queryAll

-- Generally :: (Transaction m, Conv domain, OpaRep domain ~ PersonH) => UUID -> m (Maybe domain)
runById :: Transaction m => UUID -> m (Maybe PersonH)
runById = runQueryFirst . byId

insert :: Transaction m => UUID -> String -> Int -> Maybe Gender -> m ()
insert i n a mg =
  runInsert table psn
  where
    psn :: To Maybe (To Column Person)
    psn = Person
      { id'    = Just $ constant (Id i)
      , name   = Just $ constant n
      , age    = Just $ constant a
      , gender = Just $ maybeToNullable mg
      }

update :: Transaction m => String -> Int -> Maybe Gender -> m Bool
update n a mg = (> 0) <$> runUpdate table upd condition
  where
    upd :: To Column Person -> To Maybe (To Column Person)
    upd p = p
      { id'    = Just $ id' p
      , name   = Just $ name p
      , age    = Just $ constant a
      , gender = Just $ maybeToNullable mg
      }
    condition :: To Column Person -> Column Bool
    condition p = name p .== constant n

-- Type sig can be generalized to Conv as above.
insertAndSelectAll :: Transaction m => UUID -> String -> Int -> Maybe Gender -> m [PersonH]
insertAndSelectAll i n a mg = do
  insert i n a mg
  runQuery queryAll

-- Usually no point in defining this function by itself, but it could form a larger transaction.
runInsertAndSelectAll :: MonadPool m => UUID -> String -> Int -> Maybe Gender -> m [PersonH]
runInsertAndSelectAll i n a mg = runTransaction $ insertAndSelectAll i n a mg
