open Basic
open Term
open Cic
open Uvar

(* TODO: remove the var case rule *)
type binding = { ty : Term.term ; sort : Term.term }

let extract_prod' te =
  let s1,s2,a,t = extract_prod te in
  let x,te =
    match t with
    | Lam(_,x,_,te) -> x,te
    | _ -> assert false
  in
  s1,s2,a,x,te

let mk_type0 = mk_type mk_z

(* prop will is already minimal *)
let elaborate_sort sg sort =
  if is_prop sort then
    mk_prop
  else
    fresh_uvar sg

let elaborate_cuni sg s =
  let s = elaborate_sort sg s in
  mk_succ s, mk_cuni s

let elaborate_var sg ctx var =
  Format.eprintf "debug: %a@." Pp.print_term var;
  let id = extract_var var in
  if List.mem_assoc id ctx then
    if is_cuni (List.assoc id ctx).ty then
      extract_cuni (List.assoc id ctx).ty, var
    else
    (List.assoc id ctx).sort, var
  else assert false

let if_prop s = if Cic.is_prop s then true else false

let rec elaborate_prod sg ctx s1 s2 a x b =
  let s1',a' = elaborate sg ctx (if_prop s1) a in
  let ctx' = (x,{ty=a';sort=s1'})::ctx in
  let s2',b' = elaborate sg ctx' (if_prop s2) b in
  let ty' = mk_term s1' a' in
  mk_rule s1' s2', mk_prod s1' s2' a' x ty' b'

and elaborate_cast sg ctx s1 s2 a b t =
  let s1',a' =
    if is_var t then
      try
        (List.assoc (extract_var t) ctx).sort, (List.assoc (extract_var t) ctx).ty
      with _ -> elaborate sg ctx (if_prop s1) a
    else
      elaborate sg ctx (if_prop s1) a
  in
  let s2',b' = elaborate sg ctx (if_prop s2) b in
  let s,t'  = elaborate sg ctx false t in
  mk_max s1' s2', mk_cast s1' s2' a' b' t'

and elaborate sg ctx is_prop t =
  if is_cuni t then
    let s = extract_cuni t in
    elaborate_cuni sg s
  else if is_prod t then
    let s1,s2,a,x,b = extract_prod' t in
    elaborate_prod sg ctx s1 s2 a x b
  else if is_var t then
    elaborate_var sg ctx t
  else if is_cast t then
    let s1,s2,a,b,t = extract_cast t in
    elaborate_cast sg ctx s1 s2 a b t
  else
    match t with
    | App(f, a, al) ->
      let s,f' = elaborate sg ctx is_prop f in
      let _,a' = elaborate sg ctx is_prop a in
      let _,al' = List.split (List.map (elaborate sg ctx is_prop) al) in
      s, mk_App f' a' al'
    | Lam(loc, id, Some ty, t) ->
      let s',u', ty' = elaborate_term sg ctx ty in
      let ctx' = ((id,{ty=u';sort=s'})::ctx) in
      let st,t' = elaborate sg ctx' is_prop t in
      st,mk_Lam loc id (Some ty') t'
    | Lam(loc, id, None, t) -> failwith "untyped lambdas are not supported"
    | Pi(loc, id, ta, tb) -> assert false
    | _ -> if is_prop then mk_prop,t else fresh_uvar sg, t


and elaborate_term sg ctx t =
  if is_term t then
    let s,t   = extract_term t in
    let s',t' = elaborate sg [] (if_prop s) t in
    s',t',mk_term s' t'
  else if is_univ t then
    let s = extract_univ t in
    if is_prop s then
      mk_prop, mk_cuni mk_prop, t
    else
      let s = fresh_uvar sg in
      s, mk_cuni s, mk_univ (fresh_uvar sg)
  else
    assert false

let forget_types : typed_context -> untyped_context =
  fun ctx -> List.map (fun (lc,id,_) -> (lc,id)) ctx

let ctx_of_rule_ctx sg ctx =
  let add_binding ctx (l,x,t) =
    let s',u',_ = elaborate_term sg ctx t in
    ((x,{ty=u'; sort=s'})::ctx)
  in
  List.fold_left add_binding []  ctx

let rule_elaboration sg r =
  let open Rule in
  let _,rhs' = elaborate sg (ctx_of_rule_ctx sg r.ctx) false r.rhs in
  let ctx' = forget_types r.ctx in
  {r with rhs=rhs'; ctx=ctx'}

let elaboration env e =
  let open Rule in
  let open Entry in
  let sg = Cfg.get_signature env in
  match e with
  | Decl(l,id,st,t) ->
    let _, _, t' = elaborate_term sg [] t in
    Decl(l,id,st, t')
  | Def(l,id,op,pty,te) -> (
    match pty with
    | None ->
      Def(l,id,op, None, snd @@ elaborate sg [] false te)
    | Some ty ->
      let s,_,ty'    = elaborate_term sg [] ty in
      let _, te' = elaborate sg [] (if_prop s) te in
    Def(l,id,op, Some ty', te'))
  | Rules(rs) ->
    let rs2 = List.map (Typing.check_rule sg)  rs in
    let rs' = List.map (rule_elaboration sg) rs2 in
    Rules(rs')
  | Name (l,id) -> Name(l,id)
  | _ -> assert false
