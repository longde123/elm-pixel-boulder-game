module Util.PrimeSearch exposing (Coefficients, primeSearch)

import List.Extra


type alias Coefficients =
    { a : Int
    , b : Int
    , c : Int
    }


primeSearch : Coefficients -> Int -> List Int
primeSearch coefficients maxValue =
    let
        maxElements =
            maxValue + 1

        skipSetup =
            (coefficients.a * maxElements * maxElements)
                + (coefficients.b * maxElements)
                + coefficients.c

        prime =
            findLowestPrime maxElements

        skip =
            if modBy prime skipSetup == 0 then
                skipSetup + 1

            else
                skipSetup
    in
    List.foldr
        (\_ ( acc, lastValue ) ->
            let
                nextMember =
                    modBy prime (lastValue + skip)
            in
            if nextMember < maxElements then
                ( nextMember :: acc, nextMember )

            else
                ( acc, nextMember )
        )
        ( [], 0 )
        (List.range 1 prime)
        |> Tuple.first
        |> List.drop 1


findLowestPrime : Int -> Int
findLowestPrime minimum =
    List.Extra.find
        ((<=) minimum)
        primes
        |> Maybe.withDefault 4951


primes : List Int
primes =
    [ 2
    , 3
    , 5
    , 7
    , 11
    , 13
    , 17
    , 19
    , 23
    , 29
    , 31
    , 37
    , 41
    , 43
    , 47
    , 53
    , 59
    , 61
    , 67
    , 71
    , 73
    , 79
    , 83
    , 89
    , 97
    , 101
    , 103
    , 107
    , 109
    , 113
    , 127
    , 131
    , 137
    , 139
    , 149
    , 151
    , 157
    , 163
    , 167
    , 173
    , 179
    , 181
    , 191
    , 193
    , 197
    , 199
    , 211
    , 223
    , 227
    , 229
    , 233
    , 239
    , 241
    , 251
    , 257
    , 263
    , 269
    , 271
    , 277
    , 281
    , 283
    , 293
    , 307
    , 311
    , 313
    , 317
    , 331
    , 337
    , 347
    , 349
    , 353
    , 359
    , 367
    , 373
    , 379
    , 383
    , 389
    , 397
    , 401
    , 409
    , 419
    , 421
    , 431
    , 433
    , 439
    , 443
    , 449
    , 457
    , 461
    , 463
    , 467
    , 479
    , 487
    , 491
    , 499
    , 503
    , 509
    , 521
    , 523
    , 541
    , 547
    , 557
    , 563
    , 569
    , 571
    , 577
    , 587
    , 593
    , 599
    , 601
    , 607
    , 613
    , 617
    , 619
    , 631
    , 641
    , 643
    , 647
    , 653
    , 659
    , 661
    , 673
    , 677
    , 683
    , 691
    , 701
    , 709
    , 719
    , 727
    , 733
    , 739
    , 743
    , 751
    , 757
    , 761
    , 769
    , 773
    , 787
    , 797
    , 809
    , 811
    , 821
    , 823
    , 827
    , 829
    , 839
    , 853
    , 857
    , 859
    , 863
    , 877
    , 881
    , 883
    , 887
    , 907
    , 911
    , 919
    , 929
    , 937
    , 941
    , 947
    , 953
    , 967
    , 971
    , 977
    , 983
    , 991
    , 997
    , 1009
    , 1051
    , 1103
    , 1151
    , 1201
    , 1259
    , 1301
    , 1361
    , 1409
    , 1451
    , 1511
    , 1553
    , 1601
    , 1657
    , 1709
    , 1753
    , 1801
    , 1861
    , 1901
    , 1951
    , 2003
    , 2053
    , 2111
    , 2113
    , 2153
    , 2203
    , 2251
    , 2309
    , 2351
    , 2411
    , 2459
    , 2503
    , 2551
    , 2557
    , 2609
    , 2657
    , 2707
    , 2753
    , 2767
    , 2801
    , 2851
    , 2903
    , 2953
    , 3001
    , 3061
    , 3109
    , 3163
    , 3203
    , 3251
    , 3301
    , 3359
    , 3407
    , 3457
    , 3511
    , 3557
    , 3607
    , 3659
    , 3701
    , 3761
    , 3803
    , 3851
    , 3907
    , 3967
    , 4001
    , 4051
    , 4111
    , 4153
    , 4201
    , 4253
    , 4327
    , 4357
    , 4409
    , 4451
    , 4507
    , 4561
    , 4603
    , 4651
    , 4703
    , 4751
    , 4801
    , 4861
    , 4903
    , 4951
    ]
