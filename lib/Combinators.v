Require Import StructTactics.
Require Import List.
Require Import Types.
Require Import ZArith.

Section combinators.
  Variable A : Type.
  Variable sA : Serializer A.

  Definition option_serialize (o: option A) :=
    match o with
    | None => serialize false
    | Some t => serialize true ++ serialize t
    end.

  Definition option_deserialize (bin: list bool) : option (option A * list bool) :=
    match deserialize bin with
    | None => None
    | Some (b, rest) =>
    match b with
    | false => Some (None, rest)
    | true =>
    match deserialize rest with
    | None => None
    | Some (t, rest) =>
      Some (Some t, rest)
    end
    end
    end.

  Lemma option_serialize_reversible :
    forall (o: option A) (bin: list bool),
      option_deserialize (option_serialize o ++ bin) = Some (o, bin).
  Proof.
    unfold option_deserialize, option_serialize.
    intros o bin.
    destruct o; simpl; auto.
    now rewrite Serialize_reversible.
  Qed.

  (* Global here means "redeclare this instance outside the section."
     If you leave this off, then the instance must be manually re-declared. *)
  Global Instance Option_Serializer : Serializer (option A) :=
    {
      serialize := option_serialize;
      deserialize := option_deserialize;
      Serialize_reversible := option_serialize_reversible
    }.

  Variable B : Type.
  Variable sB : Serializer B.

  Definition pair_serialize (p: A*B) :=
    let (a, b) := p in
    (serialize a) ++ (serialize b).

  Definition pair_deserialize (bin: list bool) : option ((A * B) * list bool) :=
    match deserialize bin with
    | None => None
    | Some (a, rest) =>
    match deserialize rest with
    | None => None
    | Some (b, remainder) =>
      Some ((a, b), remainder)
    end
    end.

  Lemma pair_serialize_reversible :
    forall (p: A * B) (bin: list bool),
      pair_deserialize (pair_serialize p ++ bin) = Some (p, bin).
  Proof.
    intros.
    unfold pair_serialize.
    break_match.
    unfold pair_deserialize.
    rewrite app_assoc_reverse.
    now repeat rewrite Serialize_reversible.
  Qed.

  Global Instance Pair_Serializer : Serializer (A * B) :=
    {
      serialize := pair_serialize;
      deserialize := pair_deserialize;
      Serialize_reversible := pair_serialize_reversible
    }.

  Fixpoint list_serialize_rec (ts: list A) :=
    match ts with
    | nil => nil
    | hd :: ts => (serialize hd) ++ (list_serialize_rec ts)
    end.

  Definition list_serialize (ts: list A) :=
    serialize (length ts) ++ (list_serialize_rec ts).

  Fixpoint list_deserialize_rec (count: nat) (bin: list bool) : option (list A * list bool) :=
    match count with
      | 0 => Some (nil, bin)
      | S n =>
    match deserialize bin with
      | None => None
      | Some (t, rest) =>
    match list_deserialize_rec n rest with
      | None => None
      | Some (elements, rest) => Some ((t :: elements), rest)
    end
    end
    end.

  Definition list_deserialize (bin: list bool) : option (list A * list bool) :=
    match deserialize bin with
    | None => None
    | Some (count, rest) =>
      list_deserialize_rec count rest
    end.

  Lemma list_serialize_reversible :
    forall (ts: list A) (bin: list bool),
      list_deserialize (list_serialize ts ++ bin) = Some (ts, bin).
  Proof.
    unfold list_deserialize, list_serialize.
    intros ts bin.
    rewrite app_assoc_reverse.
    rewrite Serialize_reversible.
    induction ts; auto.
    simpl.
    rewrite app_assoc_reverse.
    rewrite Serialize_reversible.
    now rewrite IHts.
  Qed.

  Global Instance List_Serializer : Serializer (list A) :=
    {
      serialize := list_serialize;
      deserialize := list_deserialize;
      Serialize_reversible := list_serialize_reversible
    }.

  Variable to : B -> A.
  Variable from : A -> B.
  Hypothesis to_from_inverse : forall b, from (to b) = b.

  Definition to_from_serialize (b : B) : list bool := serialize (to b).

  Definition to_from_deserialize bin : option (B * list bool) :=
    match deserialize(A:=A) bin with None => None
    | Some (a, bin) => Some (from a, bin)
    end.

  Lemma to_from_serialize_reversible : forall b bin,
      to_from_deserialize (to_from_serialize b ++ bin) = Some (b, bin).
  Proof.
    unfold to_from_serialize, to_from_deserialize.
    intros b bin.
    now rewrite Serialize_reversible, to_from_inverse.
  Qed.

  Global Instance To_From_Serializer : Serializer B :=
    {
      serialize := to_from_serialize;
      deserialize := to_from_deserialize;
      Serialize_reversible := to_from_serialize_reversible
    }.
End combinators.
Implicit Arguments To_From_Serializer.

Definition Z_to_nat (z : Z) : nat := 2 * (Z.abs_nat z) + Nat.b2n (0 <=? z)%Z.

Definition nat_to_Z (n : nat) : Z :=
  let abs := Z.of_nat (Nat.div2 n)
  in
  if Nat.odd n
  then abs
  else Z.opp abs.

Lemma odd_b2n :
  forall b, Nat.odd (Nat.b2n b) = b.
Proof.
  destruct b; auto.
Qed.

Lemma Z_to_nat_inverse :
  forall z, nat_to_Z (Z_to_nat z) = z.
Proof.
  unfold nat_to_Z, Z_to_nat.
  intros z.
  rewrite Nat.div2_div, plus_comm, Nat.add_b2n_double_div2, Zabs2Nat.id_abs.
  rewrite Nat.odd_add_mul_2, odd_b2n.
  break_if.
  - apply Z.leb_le in Heqb.
    now rewrite Z.abs_eq by omega.
  - apply Z.leb_gt in Heqb.
    destruct (Z.abs_spec z); intuition.
Qed.

Instance Z_Serializer : Serializer Z :=
  To_From_Serializer Nat_Serializer _ _ Z_to_nat_inverse.

