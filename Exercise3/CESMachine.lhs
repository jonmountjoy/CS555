\begin{code}
module CESMachine where

import qualified DeBruijn as S


data Inst = Int Integer
          | Bool Bool
          | Add
          | Sub
          | Mul
          | Div
          | Nand
          | Eq
          | Lt
          | Access Int
          | Close Code
          | Let
          | EndLet
          | Apply
          | Return
          | If
          | Fix
          deriving Show

          
type Code = [Inst]
data Value = BoolVal Bool | IntVal Integer | Clo Code Env
type Env = [Value]
data Slot = Value Value | Code Code | Env Env 
  deriving Show
type Stack = [Slot]
type State = (Code, Env, Stack)


compile::S.Term ->  Code
compile t = case t of
    --
    S.Var n             ->  [Access n]
    S.IntConst          ->  [Int n]
    S.Tru               ->  [Bool True]
    S.False             ->  [Bool False]
    --
    S.IntAdd  t1 t2     ->  (compile t1) ++ (compile t2) ++ [Add]
    S.IntSub  t1 t2     ->  (compile t1) ++ (compile t2) ++ [Sub]
    S.IntMul  t1 t2     ->  (compile t1) ++ (compile t2) ++ [Mul]
    S.IntDiv  t1 t2     ->  (compile t1) ++ (compile t2) ++ [Div]
    S.IntNand t1 t2     ->  (compile t1) ++ (compile t2) ++ [Nand]
    S.IntEq   t1 t2     ->  (compile t1) ++ (compile t2) ++ [Eq]
    S.IntLt   t1 t2     ->  (compile t1) ++ (compile t2) ++ [Lt]
    --
    S.Abs     t t'      ->  [Close ((compile t') ++ [Return])]
    S.App     t1 t2     ->  (compile t1) ++ (compile t2) ++ [Apply]
    S.Let     t1 t2     ->  (compile t1) ++ [Let] ++ (compile t2) ++ [EndLet]
    S.Fix     t1        ->  (compile t1) ++ [Fix]
    S.If      t1 t2 t3  ->  (compile t1) ++ (compile t2) ++ (compile t3) ++ [If]
    
step::State -> Maybe State
step state = case state of 
    --
    (Access n:c,e,s)                                        ->  Just(c,e, Value (e!!n):s)
    (Int n:c,e,s)                                           ->  Just(c,e, Value (IntVal n):s)
    (Bool b:c,e,s)                                          ->  Just(c,e, Value (BoolVal b):s)
    --
    (Add:c,e, Value (IntVal v1) : Value (IntVal v2) : s)    ->  Just(c,e, Value (IntVal (I.intAdd v1 v2)):s)
    (Sub:c,e, Value (IntVal v1) : Value (IntVal v2) : s)    ->  Just(c,e, Value (IntVal (I.intSub v1 v2)):s)
    (Mul:c,e, Value (IntVal v1) : Value (IntVal v2) : s)    ->  Just(c,e, Value (IntVal (I.intMul v1 v2)):s)
    (Div:c,e, Value (IntVal v1) : Value (IntVal v2) : s)    ->  Just(c,e, Value (IntVal (I.intDiv v1 v2)):s)
    (Nand:c,e, Value (IntVal v1) : Value (IntVal v2) : s)   ->  Just(c,e, Value (IntVal (I.intNand v1 v2)):s)
    (Eq:c,e, Value (IntVal v1) : Value (IntVal v2) : s)     ->  Just(c,e, Value (BoolVal (I.intEq v1 v2)):s)
    (Lt:c,e, Value (IntVal v1) : Value (IntVal v2) : s)     ->  Just(c,e, Value (BoolVal (I.intLt v1 v2)):s)
    --
    (Apply:c,e,Value v : Value (Clo c' e') : s)             ->  Just(c',v:e',Code c : Env e : s)
    (Let:c,e, Value v:s)                                    ->  Just(c,v:e,s)
    (EndLet:c,v:e,s)                                        ->  Just(c,e,s)
    (Close c':c,e,s)                                        ->

    
loop:: State -> State
loop state = case step state of
    Just state'         ->  loop state'
    Nothing             ->  state

eval::S.Term -> Value
eval t = case loop (compile t, [],[]) of
    (_,_,Value v:_)     ->  v

\end{code}