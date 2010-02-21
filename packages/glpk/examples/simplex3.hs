import Numeric.LinearProgramming

-- $ glpsol --cpxlp  /usr/share/doc/glpk-utils/examples/plan.lp  -o result.txt

prob = Minimize [0.03, 0.08, 0.17, 0.12, 0.15, 0.21, 0.38]

constr = Dense
    [ [1,1,1,1,1,1,1]                           :==: 2000
    , [0.15, 0.04, 0.02, 0.04, 0.2,0.01, 0.03]   :<:  60 
    , [0.03, 0.05, 0.08, 0.02, 0.06, 0.01, 0]    :<:  100 
    , [0.02, 0.04, 0.01, 0.02, 0.02, 0,    0]    :<:  40 
    , [0.02, 0.03, 0,    0,    0.01, 0,    0]    :<:  30
    , [0.7,  0.75, 0.8,  0.75, 0.8,  0.97,  0]   :>:  1500 
    , [0.02, 0.06, 0.08, 0.12, 0.02, 0.01, 0.97] :&: (250,300) 
    ]

bounds = [ 1 :&: (0,200)
         , 2 :&: (0,2500)
         , 3 :&: (400,800)
         , 4 :&: (100,700)
         , 5 :&: (0,1500) ]

main = print $ simplex prob constr bounds

