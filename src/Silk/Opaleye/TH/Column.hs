{-# LANGUAGE NoImplicitPrelude #-}
module Silk.Opaleye.TH.Column
  ( -- * TH end points
    mkId
  , makeColumnInstances
    -- * TH dependencies defined here
  , fromFieldAux
    -- * Re-exported TH dependencies
  , Typeable
  , Default (def)
  , ShowConstant (..)
  , FromField (fromField)
  , QueryRunnerColumnDefault (..)
  , Nullable
  , Column
  , fieldQueryRunnerColumn
  , unsafeCoerceColumn
  ) where

import Prelude.Compat

import Control.Monad ((<=<))
import Data.Data (Typeable)
import Data.Maybe (mapMaybe)
import Data.Profunctor.Product.Default (Default (def))
import Data.String.Conversions (StrictByteString, cs)
import Database.PostgreSQL.Simple.FromField (Conversion, Field, FromField (..), ResultError (..),
                                             returnError)
import Language.Haskell.TH
import Opaleye.Column (Column, Nullable)
import Opaleye.RunQuery (fieldQueryRunnerColumn)

import Silk.Opaleye.Compat (QueryRunnerColumnDefault (..), classP_, equalP_, unsafeCoerceColumn)
import Silk.Opaleye.ShowConstant (ShowConstant (..))
import Silk.Opaleye.TH.Util (ty)


mkId :: Name -> Q [Dec]
mkId = return . either error id <=< f <=< reify
  where
    f :: Info -> Q (Either String [Dec])
    f i = case i of
      TyConI (NewtypeD _ctx tyName _tyVars@[] con _names) ->
        case con of
          NormalC conName [(_ , innerTy)] ->
            Right <$> g tyName conName innerTy (mkName $ "un" ++ nameBase tyName)
          -- ^ This case guarantees compatibility with the previous splice
          -- if the newtype's destructor was independently defined or was
          -- not defined not use a record field destructor
          RecC conName [(desName , _ , innerTy)] ->
            Right <$> g tyName conName innerTy desName
          _ -> return $ Left "Must be a newtype without type parameters and a single destructor record field"
      TyConI NewtypeD{} -> return $ Left "Type variables aren't allowed"
      _                 -> return $ Left "Must be a newtype"

    g :: Name -> Name -> Type -> Name -> Q [Dec]
    g tyName conName innerTy desName = do
      let unsafeName      = mkUnsafeName $ nameBase tyName
          unsafeNamePrime = mkUnsafeName $ primeName $ nameBase tyName
          x =    map ($ unsafeName     ) [mkUnsafeIdSig , mkUnsafeId]
              ++ map ($ unsafeNamePrime) [mkUnsafeIdSig', mkUnsafeId']
      y <- makeColumnInstancesInternal tyName innerTy desName unsafeNamePrime
      return $ x ++ y
      where
        primeName nm = nm ++ "'"
        mkUnsafeName nm = mkName $ "unsafe" ++ nm

        mkUnsafeIdSig, mkUnsafeId, mkUnsafeIdSig', mkUnsafeId' :: Name -> Dec
        mkUnsafeIdSig  nm = SigD     nm $ ArrowT `AppT` innerTy `AppT` ConT tyName
        mkUnsafeId     nm = plainFun nm $ ConE conName
        mkUnsafeIdSig' nm = SigD     nm $ ArrowT `AppT` innerTy `AppT` (ty "Maybe" `AppT` ConT tyName)
        mkUnsafeId'    nm = plainFun nm $ VarE (mkName ".") `AppE` ConE (mkName "Just") `AppE` ConE conName

        plainFun n e = FunD n [Clause [] (NormalB e) []]

makeColumnInstances :: Name -> Name -> Name -> Name -> Q [Dec]
makeColumnInstances tyName innerTyName toDb fromDb = makeColumnInstancesInternal tyName (ConT innerTyName) toDb fromDb

makeColumnInstancesInternal :: Name -> Type -> Name -> Name -> Q [Dec]
makeColumnInstancesInternal tyName innerTy toDb fromDb = do
  tvars <- getTyVars tyName
  let predCond = map (classP_ (mkName "Typeable") . (:[])) tvars
  let outterTy = foldl AppT (ConT tyName) tvars
  return $ map ($ (predCond, outterTy)) [fromFld, showConst, queryRunnerColumn]
  where
    fromFld (predCond, outterTy)
      = InstanceD
          predCond
          (ConT (mkName "FromField") `AppT` outterTy)
          [ FunD (mkName "fromField")
            [ Clause [] (NormalB $ VarE (mkName "fromFieldAux") `AppE` VarE fromDb) [] ]
          ]
    showConst (_, outterTy)
      = InstanceD
          []
          (ConT (mkName "ShowConstant") `AppT` outterTy)
          [ TySynInstD (mkName "PGRep") (TySynEqn [outterTy] (ConT (mkName "PGRep") `AppT` innerTy))
          , FunD (mkName "constant")
            [ Clause []
              (NormalB $ InfixE
               (Just (VarE (mkName "unsafeCoerceColumn")))
               (VarE (mkName "."))
               (Just (InfixE (Just (VarE (mkName "constant"))) (VarE (mkName ".")) (Just (VarE toDb))))
              )
              []
            ]
          ]
    queryRunnerColumn (predCond, outterTy)
      = InstanceD
          (equalP_ (ConT (mkName "PGRep") `AppT` outterTy) tyVar : predCond)
          (ConT (mkName "QueryRunnerColumnDefault") `AppT` outterTy `AppT` outterTy)
          [ FunD
            (mkName "queryRunnerColumnDefault")
            [ Clause [] (NormalB $ VarE $ mkName "fieldQueryRunnerColumn") [] ]
          ]
      where tyVar = VarT $ mkName "a"

getTyVars :: Name -> Q [Type]
getTyVars n = do
  info <- reify n
  return . mapMaybe onlyPlain $ case info of
    TyConI (DataD    _ _ tvars _ _) -> tvars
    TyConI (NewtypeD _ _ tvars _ _) -> tvars
    TyConI (TySynD   _   tvars _  ) -> tvars
    _                               -> []
  where
    onlyPlain (PlainTV nv) = Just $ VarT nv
    onlyPlain _            = Nothing

fromFieldAux :: (FromField a, Typeable b) => (a -> Maybe b) -> Field -> Maybe StrictByteString -> Conversion b
fromFieldAux fromDb f mdata = case mdata of
  Just dat -> maybe (returnError ConversionFailed f (cs dat)) return . fromDb =<< fromField f mdata
  Nothing  -> returnError UnexpectedNull f ""
