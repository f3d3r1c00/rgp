## creation.r
##   - Functions for creating new GP individuals (individual initialization)
##
## RGP - a GP system for R
## 2010 Oliver Flasch (oliver.flasch@fh-koeln.de)
## with contributions of Thomas Bartz-Beielstein, Olaf Mersmann and Joerg Stork
## released under the GPL v2
##

##' @include stypes.r
NA

##' Creates a random R call object of a given type
##'
##' Creates a R call object of a given type by randomly growing an expression tree. The call
##' will denote a function, if the given type is a function type, or a value, if the given
##' type is a value type. In each step of growth, with probability \code{subtreeprob}, an
##' operator is chosen from the function set \code{funcset}. The operands are then generated
##' by recursive calls. If no subtree is generated, a constant will be generated with probability
##' \code{constprob}. If no constant is generated, an input variable will be chosen randomly.
##' The depth of the resulting expression trees can be bounded by the \code{maxdepth} parameter.
##' This function respects sType tags of functions, input variables, and constant factories.
##' Only well-typed expressions are created, all nodes in the created expression tree will be
##' tagged with their sTypes.
##'
##' @param type The type of the R call object to create randomly.
##' @param funcset The function set.
##' @param conset The set of constant factories.
##' @param inset The set of input variables, may be empty.
##' @param maxdepth The maximum expression tree depth.
##' @param constprob The probability of generating a constant in a step of growth, if no subtree
##'   is generated. If neither a subtree nor a constant is generated, a randomly chosen input variable
##'   will be generated. Defaults to \code{0.2}.
##' @param subtreeprob The probability of generating a subtree in a step of growth.
##' @param curdepth (internal) The depth of the random expression currently generated, used internally
##'   in recursive calls.
##' @param formalidx (internal) The current start index for freshly generated formal parameters, used
##'   internally in recursive calls.
##' @return A randomly generated well-typed R call object.
##' @export
randomCall <- function(type, funcset, conset, inset = inputVariableSet(), maxdepth = 8,
                       constprob = 0.2, subtreeprob = 0.5,
                       curdepth = 1, formalidx = 1) {
  if (inherits(type, "sFunctionType")) { # create a random function expression...
    if (runif(1) > subtreeprob || curdepth >= maxdepth) { # select an existing function...
      funcname <- randelt(funcset$byType[[type$string]])
      if (is.null(funcname)) stop("randomCall: Could not find a function of type ", type$string, ".")
      funcname
    } else { # create a random function expression...
      newinset <- inputVariableSet(list=Map(function(pIdx, pType) paste("x", pIdx, sep="") %::% pType,
                                     seq(formalidx, formalidx + length(type$domain) - 1),
                                     type$domain))
      newf <- new.function()
      formals(newf) <- new.alist(newinset$all)
      body(newf) <- randomCall(type$range, funcset, conset, c(inset, newinset), maxdepth,
                               constprob, subtreeprob,
                               curdepth + 1, formalidx + length(type$domain))
      newfexpr <- as.call(list(as.name("function"), formals(newf), body(newf)))
      newfexpr %::% type
    }
  } else if (inherits(type, "sBaseType")) { # create a random value expression...
    if (runif(1) > subtreeprob || curdepth >= maxdepth) { # create a terminal expression...
      if (runif(1) <= constprob || is.empty(inset$byType[[type$string]])) { # create a constant...
        constfactory <- randelt(conset$byType[[type$string]])
        if (is.null(constfactory)) stop("randomCall: Could not find a constant factory for type ", type$string, ".")
        constfactory() %::% type
      } else { # select an existing formal parameter...
        randelt(inset$byType[[type$string]])
      }
    } else { # create a nested expression...
      funcname <- randelt(funcset$byRange[[type$string]])
      if (is.null(funcname)) stop("randomCall: Could not find a function of range type ", type$string, ".")
      functype <- sType(funcname)
      funcdomaintypes <- functype$domain
      newvexpr <-
        as.call(append(funcname,
                       Map(function(domaintype) randomCall(domaintype, funcset, conset, inset, maxdepth,
                                                           constprob, subtreeprob, curdepth + 1, formalidx),
                           funcdomaintypes)))
      newvexpr %::% type
    }
  } else stop("randomCall: Invalid type requested: ", type, ".")
}

##' Creates an R expression by random growth
##'
##' Creates a random R expression by randomly growing its tree. In each step of growth,
##' with probability \code{subtreeprob}, an operator is chosen from the function set \code{funcset}.
##' The operands are then generated by recursive calls. If no subtree is generated, a constant will
##' be generated with probability \code{constprob}. If no constant is generated, an input variable
##' will be chosen randomly. The depth of the resulting expression trees can be bounded by the
##' \code{maxdepth} parameter.
##' \code{randexprFull} creates a random full expression tree of depth \code{maxdepth}. The algorithm
##' is the same as \code{randexprGrow}, with the exception that the probability of generating
##' a subtree is fixed to 1  until the desired tree depth \code{maxdepth} is reached.
##'
##' @param funcset The function set.
##' @param inset The set of input variables.
##' @param conset The set of constant factories.
##' @param maxdepth The maximum expression tree depth.
##' @param constprob The probability of generating a constant in a step of growth, if no subtree
##'   is generated. If neither a subtree nor a constant is generated, a randomly chosen input variable
##'   will be generated. Defaults to \code{0.2}.
##' @param subtreeprob The probability of generating a subtree in a step of growth.
##' @param curdepth (internal) The depth of the random expression currently generated, used internally
##'   in recursive calls.
##' @return A new R expression generated by random growth.
##' @rdname randomExpressionCreation
##' @export
randexprGrow <- function(funcset, inset, conset,
                         maxdepth = 8,
                         constprob = 0.2, subtreeprob = 0.5,
                         curdepth = 1) {
  constprob <- if (is.empty(conset$all)) 0.0 else constprob
  if (curdepth >= maxdepth) { # maximum depth reached, create terminal
    if (runif(1) <= constprob) { # create constant
      constfactory <- randelt(conset$all)
      constfactory()
    } else { # create input variable
      randelt(inset$all)
    }
  } else { # maximum depth not reached, create subtree or terminal
  	if (runif(1) <= subtreeprob) { # create subtree
      funcname <- randelt(funcset$all)
      funcarity <- arity(funcname)
      as.call(append(funcname,
                     lapply(1:funcarity, function(i) randexprGrow(funcset, inset, conset, maxdepth,
                                                                  constprob, subtreeprob, curdepth + 1))))
    } else { # create terminal
  	  if (runif(1) <= constprob) { # create constant
        constfactory <- randelt(conset$all)
        constfactory()
      } else { # create input variable
        randelt(inset$all)
      }
    }
  }
}

##' @rdname randomExpressionCreation
##' @export
randexprFull <- function(funcset, inset, conset,
                         maxdepth = 8,
                         constprob = 0.2) {
  randexprGrow(funcset, inset, conset, maxdepth, constprob, 1.0)
}

##' Creates an R function with a random expression as its body
##'
##' @param funcset The function set.
##' @param inset The set of input variables.
##' @param conset The set of constant factories.
##' @param maxdepth The maximum expression tree depth.
##' @param exprfactory The function to use for randomly creating the function's body.
##' @param constprob The probability of generating a constant in a step of growth, if no subtree
##'   is generated. If neither a subtree nor a constant is generated, a randomly chosen input variable
##'   will be generated. Defaults to \code{0.2}.
##' @return A randomly generated R function.
##' @rdname randomFunctionCreation
##' @export
randfunc <- function(funcset, inset, conset, maxdepth = 8,
                     constprob = 0.2, exprfactory = randexprGrow) {
  newf <- new.function()
  formals(newf) <- new.alist(inset$all)
  body(newf) <- exprfactory(funcset, inset, conset, maxdepth, constprob = constprob)
  newf
}

##' @rdname randomFunctionCreation
##' @export
randfuncRampedHalfAndHalf <- function(funcset, inset, conset, maxdepth = 8, constprob = 0.2) {
  if (runif(1) > 0.5)
    randfunc(funcset, inset, conset, maxdepth, exprfactory = randexprFull, constprob = constprob)
  else
    randfunc(funcset, inset, conset, maxdepth, exprfactory = randexprGrow, constprob = constprob)
}

##' Creates an R expression by random growth respecting type constraints
##'
##' Creates a random R expression by randomly growing its tree. In each step of growth,
##' with probability \code{subtreeprob}, an operator is chosen from the function set \code{funcset}.
##' The operands are then generated by recursive calls. If no subtree is generated, a constant will
##' be generated with probability \code{constprob}. If no constant is generated, an input variable
##' will be chosen randomly. The depth of the resulting expression trees can be bounded by the
##' \code{maxdepth} parameter.
##' In contrast to \code{randexprGrow}, this function respects sType tags of functions, input
##' variables, and constant factories. Only well-typed expressions are created.
##' \code{randexprTypedFull} creates a random full expression tree of depth \code{maxdepth},
##' respecting type constraints.
##' All nodes in the created expressions will be tagged with their sTypes.
##'
##' @param type The (range) type the created expression should have.
##' @param funcset The function set.
##' @param inset The set of input variables.
##' @param conset The set of constant factories.
##' @param maxdepth The maximum expression tree depth.
##' @param constprob The probability of generating a constant in a step of growth, if no subtree
##'   is generated. If neither a subtree nor a constant is generated, a randomly chosen input variable
##'   will be generated. Defaults to \code{0.2}.
##' @param subtreeprob The probability of generating a subtree in a step of growth.
##' @param curdepth (internal) The depth of the random expression currently generated, used internally
##'   in recursive calls.
##' @return A new R expression generated by random growth.
##' @rdname randomExpressionCreationTyped
##' @export
randexprTypedGrow <- function(type, funcset, inset, conset,
                              maxdepth = 8,
                              constprob = 0.2, subtreeprob = 0.5,
                              curdepth = 1) {
  if (is.null(type)) stop("randexprTypedGrow: Type must not be NULL.")
  constprob <- if (is.empty(conset$all)) 0.0 else constprob
  typeString <- type$string
  insetTypes <- Map(sType, inset$all)
  if (curdepth >= maxdepth) { # maximum depth reached, create terminal of correct type
    randterminalTyped(typeString, inset, conset, constprob) %::% type
  } else { # maximum depth not reached, create subtree or terminal
  	if (runif(1) <= subtreeprob) { # create subtree of correct type
      funcname <- randelt(funcset$byRange[[typeString]])
      if (is.null(funcname)) stop("randexprTypedGrow: Could not find a function of range type ", typeString, ".")
      functype <- sType(funcname)
      funcdomaintypes <- functype$domain
      newSubtree <-
        as.call(append(funcname,
                       Map(function(domaintype) randexprTypedGrow(domaintype, funcset, inset, conset, maxdepth,
                                                                  constprob, subtreeprob, curdepth + 1),
                           funcdomaintypes)))
      ## the type of the generated subtree is a function type with the input variable types as domain types...
      newSubtreeType <- insetTypes %->% type
      newSubtree %::% newSubtreeType
    } else { # create terminal of correct type
  	  randterminalTyped(typeString, inset, conset, constprob) %::% type
    }
  }
}

##' @rdname randomExpressionCreationTyped
##' @export
randexprTypedFull <- function(type, funcset, inset, conset,
                              maxdepth = 8,
                              constprob = 0.2) {
  randexprTypedGrow(type, funcset, inset, conset, maxdepth, constprob, 1.0)
}

##' Creates a well-typed R function with a random expression as its body
##'
##' @param type The range type of the random function to create.
##' @param funcset The function set.
##' @param inset The set of input variables.
##' @param conset The set of constant factories.
##' @param maxdepth The maximum expression tree depth.
##' @param constprob The probability of generating a constant in a step of growth, if no subtree
##'   is generated. If neither a subtree nor a constant is generated, a randomly chosen input variable
##'   will be generated. Defaults to \code{0.2}.
##' @param exprfactory The function to use for randomly creating the function's body.
##' @return A randomly generated well-typed R function.
##' @rdname randomFunctionCreationTyped
##' @export
randfuncTyped <- function(type, funcset, inset, conset, maxdepth = 8,
                          constprob = 0.2, exprfactory = randexprTypedGrow) {
  newf <- new.function()
  formals(newf) <- new.alist(inset$all)
  body(newf) <- exprfactory(type, funcset, inset, conset, maxdepth, constprob = constprob)
  newf
}

##' @rdname randomFunctionCreationTyped
##' @export
randfuncTypedRampedHalfAndHalf <- function(type, funcset, inset, conset, maxdepth = 8, constprob = 0.2) {
  if (runif(1) > 0.5)
    randfuncTyped(type, funcset, inset, conset, maxdepth, exprfactory = randexprTypedFull, constprob = constprob)
  else
    randfuncTyped(type, funcset, inset, conset, maxdepth, exprfactory = randexprTypedGrow, constprob = constprob)
}

##' Create a random terminal node
##'
##' @param typeString The string label of the type of the random terminal node to create.
##' @param inset The set of input variables.
##' @param conset The set of constant factories.
##' @param constprob The probability of creating a constant versus an input variable.
##' @return A random terminal node, i.e. an input variable or a constant.
randterminalTyped <- function(typeString, inset, conset, constprob) {
  if (runif(1) <= constprob) { # create constant of correct type
    constfactory <- randelt(conset$byRange[[typeString]])
    if (is.null(constfactory)) stop("randterminalTyped: Could not find a constant factory for type ", typeString, ".")
    constfactory()
  } else { # create input variable of correct type
    invar <- randelt(inset$byRange[[typeString]])
    if (is.null(invar)) { # there are no input variables of the requested type, try to create a contant instead
      constfactory <- randelt(conset$byRange[[typeString]])
      if (is.null(constfactory)) stop("randterminalTyped: Could not find a constant factory for type ", typeString, ".")
      constfactory()
    } else {
      invar
    }
  }
}
