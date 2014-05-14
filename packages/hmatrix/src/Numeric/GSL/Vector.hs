-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.GSL.Vector
-- Copyright   :  (c) Alberto Ruiz 2007
-- License     :  GPL
-- Maintainer  :  Alberto Ruiz
-- Stability   :  provisional
--
-- Low level interface to vector operations.
--
-----------------------------------------------------------------------------

module Numeric.GSL.Vector (
    sumF, sumR, sumQ, sumC,
    prodF, prodR, prodQ, prodC,
    FunCodeS(..), toScalarR, toScalarF, toScalarC, toScalarQ,
    FunCodeV(..), vectorMapR, vectorMapC, vectorMapF, vectorMapQ,
    FunCodeSV(..), vectorMapValR, vectorMapValC, vectorMapValF, vectorMapValQ,
    FunCodeVV(..), vectorZipR, vectorZipC, vectorZipF, vectorZipQ,
    RandDist(..), randomVector,
    saveMatrix,
    fwriteVector, freadVector, fprintfVector, fscanfVector
) where

import Data.Packed
import Numeric.GSL.Internal hiding (TV,TM,TCV,TCM)
import Numeric.Vectorized(
    sumF, sumR, sumQ, sumC,
    prodF, prodR, prodQ, prodC,
    FunCodeS(..), toScalarR, toScalarF, toScalarC, toScalarQ,
    FunCodeV(..),
    FunCodeSV(..),
    FunCodeVV(..)
   )

import Data.Complex
import Foreign.Marshal.Alloc(free)
import Foreign.Marshal.Array(newArray)
import Foreign.Ptr(Ptr)
import Foreign.C.Types
import Foreign.C.String(newCString)
import System.IO.Unsafe(unsafePerformIO)
import Control.Monad(when)

fromei x = fromIntegral (fromEnum x) :: CInt

------------------------------------------------------------------

vectorMapAux fun code v = unsafePerformIO $ do
    r <- createVector (dim v)
    app2 (fun (fromei code)) vec v vec r "vectorMapAux"
    return r

vectorMapValAux fun code val v = unsafePerformIO $ do
    r <- createVector (dim v)
    pval <- newArray [val]
    app2 (fun (fromei code) pval) vec v vec r "vectorMapValAux"
    free pval
    return r

vectorZipAux fun code u v = unsafePerformIO $ do
    r <- createVector (dim u)
    when (dim u > 0) $ app3 (fun (fromei code)) vec u vec v vec r "vectorZipAux"
    return r

---------------------------------------------------------------------


-- | map of real vectors with given function
vectorMapR :: FunCodeV -> Vector Double -> Vector Double
vectorMapR = vectorMapAux c_vectorMapR

foreign import ccall unsafe "gsl-aux.h mapR" c_vectorMapR :: CInt -> TVV

-- | map of complex vectors with given function
vectorMapC :: FunCodeV -> Vector (Complex Double) -> Vector (Complex Double)
vectorMapC oper = vectorMapAux c_vectorMapC (fromei oper)

foreign import ccall unsafe "gsl-aux.h mapC" c_vectorMapC :: CInt -> TCVCV

-- | map of real vectors with given function
vectorMapF :: FunCodeV -> Vector Float -> Vector Float
vectorMapF = vectorMapAux c_vectorMapF

foreign import ccall unsafe "gsl-aux.h mapF" c_vectorMapF :: CInt -> TFF

-- | map of real vectors with given function
vectorMapQ :: FunCodeV -> Vector (Complex Float) -> Vector (Complex Float)
vectorMapQ = vectorMapAux c_vectorMapQ

foreign import ccall unsafe "gsl-aux.h mapQ" c_vectorMapQ :: CInt -> TQVQV

-------------------------------------------------------------------

-- | map of real vectors with given function
vectorMapValR :: FunCodeSV -> Double -> Vector Double -> Vector Double
vectorMapValR oper = vectorMapValAux c_vectorMapValR (fromei oper)

foreign import ccall unsafe "gsl-aux.h mapValR" c_vectorMapValR :: CInt -> Ptr Double -> TVV

-- | map of complex vectors with given function
vectorMapValC :: FunCodeSV -> Complex Double -> Vector (Complex Double) -> Vector (Complex Double)
vectorMapValC = vectorMapValAux c_vectorMapValC

foreign import ccall unsafe "gsl-aux.h mapValC" c_vectorMapValC :: CInt -> Ptr (Complex Double) -> TCVCV

-- | map of real vectors with given function
vectorMapValF :: FunCodeSV -> Float -> Vector Float -> Vector Float
vectorMapValF oper = vectorMapValAux c_vectorMapValF (fromei oper)

foreign import ccall unsafe "gsl-aux.h mapValF" c_vectorMapValF :: CInt -> Ptr Float -> TFF

-- | map of complex vectors with given function
vectorMapValQ :: FunCodeSV -> Complex Float -> Vector (Complex Float) -> Vector (Complex Float)
vectorMapValQ oper = vectorMapValAux c_vectorMapValQ (fromei oper)

foreign import ccall unsafe "gsl-aux.h mapValQ" c_vectorMapValQ :: CInt -> Ptr (Complex Float) -> TQVQV

-------------------------------------------------------------------

-- | elementwise operation on real vectors
vectorZipR :: FunCodeVV -> Vector Double -> Vector Double -> Vector Double
vectorZipR = vectorZipAux c_vectorZipR

foreign import ccall unsafe "gsl-aux.h zipR" c_vectorZipR :: CInt -> TVVV

-- | elementwise operation on complex vectors
vectorZipC :: FunCodeVV -> Vector (Complex Double) -> Vector (Complex Double) -> Vector (Complex Double)
vectorZipC = vectorZipAux c_vectorZipC

foreign import ccall unsafe "gsl-aux.h zipC" c_vectorZipC :: CInt -> TCVCVCV

-- | elementwise operation on real vectors
vectorZipF :: FunCodeVV -> Vector Float -> Vector Float -> Vector Float
vectorZipF = vectorZipAux c_vectorZipF

foreign import ccall unsafe "gsl-aux.h zipF" c_vectorZipF :: CInt -> TFFF

-- | elementwise operation on complex vectors
vectorZipQ :: FunCodeVV -> Vector (Complex Float) -> Vector (Complex Float) -> Vector (Complex Float)
vectorZipQ = vectorZipAux c_vectorZipQ

foreign import ccall unsafe "gsl-aux.h zipQ" c_vectorZipQ :: CInt -> TQVQVQV

-----------------------------------------------------------------------

data RandDist = Uniform  -- ^ uniform distribution in [0,1)
              | Gaussian -- ^ normal distribution with mean zero and standard deviation one
              deriving Enum

-- | Obtains a vector of pseudorandom elements from the the mt19937 generator in GSL, with a given seed. Use randomIO to get a random seed.
randomVector :: Int      -- ^ seed
             -> RandDist -- ^ distribution
             -> Int      -- ^ vector size
             -> Vector Double
randomVector seed dist n = unsafePerformIO $ do
    r <- createVector n
    app1 (c_random_vector (fi seed) ((fi.fromEnum) dist)) vec r "randomVector"
    return r

foreign import ccall unsafe "random_vector" c_random_vector :: CInt -> CInt -> TV

--------------------------------------------------------------------------------

-- | Saves a matrix as 2D ASCII table.
saveMatrix :: FilePath
           -> String     -- ^ format (%f, %g, %e)
           -> Matrix Double
           -> IO ()
saveMatrix filename fmt m = do
    charname <- newCString filename
    charfmt <- newCString fmt
    let o = if orderOf m == RowMajor then 1 else 0
    app1 (matrix_fprintf charname charfmt o) mat m "matrix_fprintf"
    free charname
    free charfmt

foreign import ccall unsafe "matrix_fprintf" matrix_fprintf :: Ptr CChar -> Ptr CChar -> CInt -> TM

--------------------------------------------------------------------------------

-- | Loads a vector from an ASCII file (the number of elements must be known in advance).
fscanfVector :: FilePath -> Int -> IO (Vector Double)
fscanfVector filename n = do
    charname <- newCString filename
    res <- createVector n
    app1 (gsl_vector_fscanf charname) vec res "gsl_vector_fscanf"
    free charname
    return res

foreign import ccall unsafe "vector_fscanf" gsl_vector_fscanf:: Ptr CChar -> TV

-- | Saves the elements of a vector, with a given format (%f, %e, %g), to an ASCII file.
fprintfVector :: FilePath -> String -> Vector Double -> IO ()
fprintfVector filename fmt v = do
    charname <- newCString filename
    charfmt <- newCString fmt
    app1 (gsl_vector_fprintf charname charfmt) vec v "gsl_vector_fprintf"
    free charname
    free charfmt

foreign import ccall unsafe "vector_fprintf" gsl_vector_fprintf :: Ptr CChar -> Ptr CChar -> TV

-- | Loads a vector from a binary file (the number of elements must be known in advance).
freadVector :: FilePath -> Int -> IO (Vector Double)
freadVector filename n = do
    charname <- newCString filename
    res <- createVector n
    app1 (gsl_vector_fread charname) vec res "gsl_vector_fread"
    free charname
    return res

foreign import ccall unsafe "vector_fread" gsl_vector_fread:: Ptr CChar -> TV

-- | Saves the elements of a vector to a binary file.
fwriteVector :: FilePath -> Vector Double -> IO ()
fwriteVector filename v = do
    charname <- newCString filename
    app1 (gsl_vector_fwrite charname) vec v "gsl_vector_fwrite"
    free charname

foreign import ccall unsafe "vector_fwrite" gsl_vector_fwrite :: Ptr CChar -> TV

type PF = Ptr Float                             --
type PD = Ptr Double                            --
type PQ = Ptr (Complex Float)                   --
type PC = Ptr (Complex Double)                  --
type TF = CInt -> PF -> IO CInt                 --
type TFF = CInt -> PF -> TF                     --
type TFV = CInt -> PF -> TV                     --
type TVF = CInt -> PD -> TF                     --
type TFFF = CInt -> PF -> TFF                   --
type TV = CInt -> PD -> IO CInt                 --
type TVV = CInt -> PD -> TV                     --
type TVVV = CInt -> PD -> TVV                   --
type TFM = CInt -> CInt -> PF -> IO CInt        --
type TFMFM =  CInt -> CInt -> PF -> TFM         --
type TFMFMFM =  CInt -> CInt -> PF -> TFMFM     --
type TM = CInt -> CInt -> PD -> IO CInt         --
type TMM =  CInt -> CInt -> PD -> TM            --
type TVMM = CInt -> PD -> TMM                   --
type TMVMM = CInt -> CInt -> PD -> TVMM         --
type TMMM =  CInt -> CInt -> PD -> TMM          --
type TVM = CInt -> PD -> TM                     --
type TVVM = CInt -> PD -> TVM                   --
type TMV = CInt -> CInt -> PD -> TV             --
type TMMV = CInt -> CInt -> PD -> TMV           --
type TMVM = CInt -> CInt -> PD -> TVM           --
type TMMVM = CInt -> CInt -> PD -> TMVM         --
type TCM = CInt -> CInt -> PC -> IO CInt        --
type TCVCM = CInt -> PC -> TCM                  --
type TCMCVCM = CInt -> CInt -> PC -> TCVCM      --
type TMCMCVCM = CInt -> CInt -> PD -> TCMCVCM   --
type TCMCMCVCM = CInt -> CInt -> PC -> TCMCVCM  --
type TCMCM = CInt -> CInt -> PC -> TCM          --
type TVCM = CInt -> PD -> TCM                   --
type TCMVCM = CInt -> CInt -> PC -> TVCM        --
type TCMCMVCM = CInt -> CInt -> PC -> TCMVCM    --
type TCMCMCM = CInt -> CInt -> PC -> TCMCM      --
type TCV = CInt -> PC -> IO CInt                --
type TCVCV = CInt -> PC -> TCV                  --
type TCVCVCV = CInt -> PC -> TCVCV              --
type TCVV = CInt -> PC -> TV                    --
type TQV = CInt -> PQ -> IO CInt                --
type TQVQV = CInt -> PQ -> TQV                  --
type TQVQVQV = CInt -> PQ -> TQVQV              --
type TQVF = CInt -> PQ -> TF                    --
type TQM = CInt -> CInt -> PQ -> IO CInt        --
type TQMQM = CInt -> CInt -> PQ -> TQM          --
type TQMQMQM = CInt -> CInt -> PQ -> TQMQM      --
type TCMCV = CInt -> CInt -> PC -> TCV          --
type TVCV = CInt -> PD -> TCV                   --
type TCVM = CInt -> PC -> TM                    --
type TMCVM = CInt -> CInt -> PD -> TCVM         --
type TMMCVM = CInt -> CInt -> PD -> TMCVM       --

