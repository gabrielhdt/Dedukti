type name
type var
type ty
type term
type const

type hyp
type thm

val mk_name : string list -> string -> name


val mk_var : name -> ty -> var


val mk_varType : name -> ty


val mk_appTerm : term -> term -> term

val mk_absTerm : var -> term -> term

val mk_varTerm : var -> term

val term_of_const : const -> ty -> term


val const_of_name : name -> const


val mk_hyp : term list -> hyp


val mk_axiom : hyp -> term -> thm

val thm_of_const : const -> thm


val mk_const : name -> term -> unit

val mk_thm : term -> hyp -> thm -> unit

val debug : unit -> unit

val to_string : unit -> string
