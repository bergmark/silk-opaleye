{-# OPTIONS -fno-warn-orphans -fno-warn-deprecations #-}
{-# LANGUAGE
    FlexibleInstances
  , MultiParamTypeClasses
  , NoMonomorphismRestriction
  , TypeFamilies
  , UndecidableInstances
  #-}
module Silk.Opaleye.ShowConstant
  ( ShowConstant (..)
  , TString (..)
  , TInt4 (..)
  , TInt8 (..)
  , TDouble (..)
  , TUUID (..)
  , TDate (..)
  , TTimestamptz (..)
  , TTimestamp (..)
  , TTime (..)
  , TCIText (..)
  , TOrd
  , toPGBool
  , fromPGBool
  ) where

import Data.CaseInsensitive (CI)
import Data.Int (Int64)
import Data.String.Conversions
import Data.Time (Day, LocalTime, TimeOfDay, UTCTime)
import Data.UUID (UUID)
import qualified Data.Text      as S
import qualified Data.Text.Lazy as L

import Opaleye.Column (Column, unsafeCoerce)
import Opaleye.Internal.RunQuery
import Opaleye.PGTypes
import Opaleye.RunQuery

class ShowConstant a where
  type PGRep a :: *
  constant :: a -> Column a

instance ShowConstant [Char] where
  type PGRep String = PGText
  constant = constantString
instance QueryRunnerColumnDefault [Char] [Char] where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column String -> Column (PGRep String))

instance ShowConstant StrictText where
  type PGRep S.Text = PGText
  constant = constantString
instance QueryRunnerColumnDefault S.Text S.Text where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column S.Text -> Column (PGRep S.Text))

instance ShowConstant LazyText where
  type PGRep L.Text = PGText
  constant = constantString
instance QueryRunnerColumnDefault L.Text L.Text where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column L.Text -> Column (PGRep L.Text))

instance ShowConstant Int where
  type PGRep Int = PGInt4
  constant = constantInt4
instance QueryRunnerColumnDefault Int Int where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column Int -> Column (PGRep Int))

instance ShowConstant Int64 where
  type PGRep Int64 = PGInt8
  constant = constantInt8
instance QueryRunnerColumnDefault Int64 Int64 where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column Int64 -> Column (PGRep Int64))

instance ShowConstant Double where
  type PGRep Double = PGFloat8
  constant = constantDouble
instance QueryRunnerColumnDefault Double Double where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column Double -> Column (PGRep Double))

instance ShowConstant Bool where
  type PGRep Bool = PGBool ; constant = constantBool
instance QueryRunnerColumnDefault Bool Bool where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column Bool -> Column PGBool)

instance ShowConstant UUID where
  type PGRep UUID = PGUuid
  constant = constantUUID
instance QueryRunnerColumnDefault UUID UUID where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column UUID -> Column PGUuid)

instance ShowConstant Day where
  type PGRep Day = PGDate
  constant = constantDay
instance QueryRunnerColumnDefault Day Day where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column Day -> Column (PGRep Day))

instance ShowConstant UTCTime where
  type PGRep UTCTime = PGTimestamptz
  constant = constantTimestamptz
instance QueryRunnerColumnDefault UTCTime UTCTime where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column UTCTime -> Column PGTimestamptz)

instance ShowConstant LocalTime where
  type PGRep LocalTime = PGTimestamp
  constant = constantTimestamp
instance QueryRunnerColumnDefault LocalTime LocalTime where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column LocalTime -> Column (PGRep LocalTime))

instance ShowConstant TimeOfDay where
  type PGRep TimeOfDay = PGTime
  constant = constantTime
instance QueryRunnerColumnDefault TimeOfDay TimeOfDay where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column TimeOfDay -> Column (PGRep TimeOfDay))

instance ShowConstant (CI S.Text) where
  type PGRep (CI S.Text) = PGCitext
  constant = constantCIText
instance QueryRunnerColumnDefault (CI S.Text) (CI S.Text) where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column (CI S.Text) -> Column (PGRep (CI S.Text)))

instance ShowConstant (CI L.Text) where
  type PGRep (CI L.Text) = PGCitext
  constant = constantCIText
instance QueryRunnerColumnDefault (CI L.Text) (CI L.Text) where
  queryRunnerColumnDefault = qrcDef (unsafeCoerce :: Column (CI L.Text) -> Column (PGRep (CI L.Text)))

qrcDef :: QueryRunnerColumnDefault b c => (Column a -> Column b) -> QueryRunnerColumn a c
qrcDef u = queryRunnerColumn u id queryRunnerColumnDefault

class TString a where
  constantString :: a -> Column a

instance TString [Char] where
  constantString = unsafeCoerce . pgString

instance TString StrictText where
  constantString = unsafeCoerce . pgStrictText

instance TString LazyText where
  constantString = unsafeCoerce . pgLazyText

class TInt4 a where
  constantInt4 :: a -> Column a

class TInt8 a where
  constantInt8 :: a -> Column a

instance TInt4 Int where
  constantInt4 = unsafeCoerce . pgInt4

instance TInt8 Int64 where
  constantInt8 = unsafeCoerce . pgInt8

class TDouble a where
  constantDouble :: a -> Column a

instance TDouble Double where
  constantDouble = unsafeCoerce . pgDouble

class TBool a where
  constantBool :: a -> Column a

toPGBool :: Column Bool -> Column PGBool
toPGBool = unsafeCoerce

fromPGBool :: Column PGBool -> Column Bool
fromPGBool = unsafeCoerce

instance TBool Bool where
  constantBool = unsafeCoerce . pgBool

class TUUID a where
  constantUUID :: a -> Column a

instance TUUID UUID where
  constantUUID = unsafeCoerce . pgUUID

class TDate a where
  constantDay :: a -> Column a

instance TDate Day where
  constantDay = unsafeCoerce . pgDay

class TTimestamptz a where
  constantTimestamptz :: a -> Column a

instance TTimestamptz UTCTime where
  constantTimestamptz = unsafeCoerce . pgUTCTime

class TTimestamp a where
  constantTimestamp :: a -> Column a

instance TTimestamp LocalTime where
  constantTimestamp = unsafeCoerce . pgLocalTime

class TTime a where
  constantTime :: a -> Column a

instance TTime TimeOfDay where
  constantTime = unsafeCoerce . pgTimeOfDay

class TCIText a where
  constantCIText :: a -> Column a

instance TCIText (CI StrictText) where
  constantCIText = unsafeCoerce . pgCiStrictText

instance TCIText (CI LazyText) where
  constantCIText = unsafeCoerce . pgCiLazyText

class TOrd a

instance TOrd Int
instance TOrd Int64
instance TOrd UTCTime
