\begin{code}
module CE3RMachine where
import qualified DeBruijn as D 
import qualified AbstractSyntax as S
import qualified IntegerArithmetic as I

data Inst = Int Integer Integer
          | Bool Integer Bool
          | Op Op
          | Access Integer Int
          | Close Integer Code
          | Apply1
          | Apply2
          | Return
          | If
          | Fix
          deriving (Show, Eq)
data Op = Add
        | Sub
        | Mul
        | Div
        | Nand
        | Eq
        | Lt
        deriving (Show, Eq)
type Code = [Inst]
data Value = BoolVal Bool 
           | IntVal Integer 
           | Clo Code Env 
           | Empty 
           deriving (Show, Eq)
type Env = [Value]
type Registers =(Value,Value,Value)
type State = (Code, Env, Registers)


compile::D.Term ->  Code
compile t = case t of
\end{code}
Lazy If Statement:
The three terms of the if are placed on all three registers.  If the statement 
is true the value on register 2 is placed on register 1, if it is false the 
value on register 3 is placed on register 1.  The reason for this is the terms 
in the if statement only receive the continuation if the conditional has 
determined this action is appropriate.  In this way the if is kept lazy.
\begin{code}  
  D.App (D.If t1 t2 t3) k   -> (fillReg t1 t2 t3)++[If]++(getCode 2 k)++[Apply1]
  D.App (D.App t1 t2) t3    ->(fillReg t1 t2 t3) ++ [Apply2]
  D.App t1 (D.IntAdd t2 t3) ->(fillReg t1 t2 t3) ++ [Op Add]
  D.App t1 (D.IntSub t2 t3) ->(fillReg t1 t2 t3) ++ [Op Sub]
  D.App t1 (D.IntMul t2 t3) ->(fillReg t1 t2 t3) ++ [Op Mul]
  D.App t1 (D.IntDiv t2 t3) ->(fillReg t1 t2 t3) ++ [Op Div]
  D.App t1 (D.IntNand t2 t3)->(fillReg t1 t2 t3) ++ [Op Nand]
  D.App t1 (D.IntEq t2 t3)  ->(fillReg t1 t2 t3) ++ [Op Eq]  
  D.App t1 (D.IntLt t2 t3)  ->(fillReg t1 t2 t3) ++ [Op Lt]
\end{code}
App Fix and Let Fix:
From the cps code two cases were handled the app fix and the let fix.  The app 
fix ensured that the fix term was in tail position while the let fix ensured 
that when the variable assigned to fix was called the fix was then applied in 
tail position.  For this reason the app fix code places the the term being fixed 
onto register 2.  The let fix term which is now in cps simply treats the let as
syntactic sugar and converts it to an application.   
\begin{code} 
  D.Let t1 t2               -> compile (D.App (D.Abs S.TypeBool t2) t1)
  D.App t1 (D.Fix t2)       ->(getCode 1 t1) ++ (getCode 2 t2) ++[Fix]++[Apply1]    
  D.App t1 t2               ->(getCode 1 t1) ++ (getCode 2 t2) ++ [Apply1]  
  otherwise                 ->(getCode 1 t)  

fillReg::D.Term -> D.Term -> D.Term -> Code
fillReg t1 t2 t3 = (getCode 1 t1) ++ (getCode 2 t2) ++ (getCode 3 t3)

getCode:: Integer -> D.Term -> Code
getCode i t = case t of
    D.Var x              -> [Access i x]
    D.Tru                -> [Bool i True]
    D.Fls                -> [Bool i False]
    D.IntConst x         -> [Int i x]
    D.Abs _ (D.Abs _ t1) -> [Close i (compile t1)]
    D.Abs _ t1           -> [Close i (compile t1)]
    D.App _ _            -> [Close i (compile t)]
    D.Let _ _            -> [Close i (compile t)]
    D.If t1 t2 t3        -> (fillReg t1 t2 t3)++[If]
    _                    -> error ("incorrect term in getCode"++ (show t))

step::State -> Maybe State
step state = case state of 
\end{code}
The code for Int, Bool, Access and Close each simply put a value on one of three 
registers.
\begin{code}
  ((Int i x):c,e,regs)            -> Just (c,e,(getReg (IntVal x) i regs))
  ((Bool i x):c,e,regs)           -> Just (c,e,(getReg (BoolVal x) i regs))
  --
  ((Access i x):c,e,regs)         -> case e!!x of
    (Clo t@(Close 2 ((Close i c1:c2)):[Fix]) _)  -> Just (t++c, e, regs)
    v                                            -> Just (c,e,(getReg v i regs))
  --
  ((Close i x):c,e,regs)          -> Just (c,e,(getReg (Clo x e) i regs))
\end{code}
Apply1 - will do a single application so the value on register 2 is placed at 
the head of the environment, or index 0.
Apply2 - will do 2 applications so the inner most abstraction will return an 
abstraction which means that the value on register 2 will be for the free 
variable in the abstraction produced because of this we know that the debrujin 
value in this case will be 1 rather than 0. 
\begin{code}
  (Apply1:c,e,((Clo c1 e1),v2,v3))-> Just (c1,v2:e1,(Empty,Empty,Empty))
  (Apply2:c,e,((Clo c1 e1),v2,v3))-> Just (c1,v3:v2:e1,(Empty,Empty,Empty))
  --
\end{code}
In order for our if to be lazy in cps our then and else terms will be 
abstractions looking for a continuation.  This translates to the if statement 
placing a closure on register 1 that will be applied to the continuation to be 
placed on register 2.
\begin{code}
  (If:c,e,(BoolVal t1,t2,t3))     -> if t1 then Just (c,e,(t2,Empty,Empty))
                                     else Just (c,e,(t3,Empty,Empty))
\end{code}
The fix instruction is pattern matched with the closure on register 2, the 
register is updated and the environment is updates to remove any variables added 
by the previous recursion.
\begin{code}                               
  (Fix:c, e, (v1, (Clo((Close i c1):c2) e2), v3))        ->
    let fClo = (Clo ((Close 2 (Close i c1:c2)):[Fix]) [])
       in Just (c, e, (v1, (Clo (c1++c2)(fClo:(fixRemove e fClo))),v3))
  ((Op o):c,e,((Clo c1 e1),IntVal v2, IntVal v3))  -> 
    Just(c1,(opHelp o v2 v3):e1, (Empty, Empty, Empty))
  otherwise                       -> Nothing

fixRemove:: Env->Value-> Env
fixRemove e fClo= let e' = reverse e
                 in take (fixRemoveHelper e' fClo 0) e'

fixRemoveHelper:: Env -> Value -> Int -> Int
fixRemoveHelper []  _  n = n
fixRemoveHelper (e:es) v n = if(e==v) then n else fixRemoveHelper es v (n+1)

\end{code}
All binary ops take two values and produce a single value, these values come 
from register 2 and 3, the result is put onto the environment.
\begin{code}
opHelp:: Op -> Integer -> Integer -> Value
opHelp o v1 v2 = case o of 
  Add -> IntVal (I.intAdd v1 v2)
  Sub -> IntVal (I.intSub v1 v2)
  Mul -> IntVal (I.intMul v1 v2) 
  Div -> IntVal (I.intDiv v1 v2) 
  Nand-> IntVal (I.intNand v1 v2)
  Eq  -> BoolVal (I.intEq v1 v2) 
  Lt  -> BoolVal (I.intLt v1 v2) 

getReg:: Value -> Integer -> Registers -> Registers
getReg v' 1 (v1, v2, v3) = (v',v2,v3)
getReg v' 2 (v1, v2, v3) = (v1,v',v3)
getReg v' 3 (v1, v2, v3) = (v1,v2,v')

loop:: State -> State
loop state = case step state of
    Just state'         ->  loop state'
    Nothing             ->  state

eval::D.Term -> Value
eval t = case loop (compile t, [],(Empty,Empty,Empty)) of
    (_,_,(v,_,_))     ->  v              
\end{code}