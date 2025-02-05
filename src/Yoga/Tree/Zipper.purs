module Yoga.Tree.Zipper where

import Prelude
import Control.Alt ((<|>))
import Control.Comonad.Cofree (head, tail, (:<))
import Data.Array (drop, reverse, take, uncons, (!!), (:))
import Data.Maybe (Maybe(Just, Nothing))
import Yoga.Tree (Forest, Tree, mkTree, modifyNodeValue, setNodeValue)

-- | The `Loc` type describes the location of a `Node` inside a `Tree`. For this
-- | we store the current `Node`, the sibling nodes that appear before the current
-- | node, the sibling nodes that appear after the current node, and a `Array` of
-- | `Loc`ations that store the parent node locations up to the root of the three.
-- |
-- | So, effectively, the `parents` field records the path travelled in the
-- | tree to reach the level of the current `Node` starting from the tree's root,
-- | and the `before` and `after` fields describe its location in the current
-- | level.
newtype Loc a = Loc
  { node ∷ Tree a
  , before ∷ Forest a
  , after ∷ Forest a
  , parents ∷ Array (Loc a)
  }

instance eqLoc ∷ Eq a => Eq (Loc a) where
  eq (Loc r1) (Loc r2) =
    (r1.node == r2.node)
      && (r1.before == r2.before)
      && (r1.after == r2.after)
      && (r1.parents == r2.parents)

-- -- Cursor movement
-- | Move the cursor to the next sibling.
next ∷ ∀ a. Loc a -> Maybe (Loc a)
next (Loc r) = case uncons r.after of
  Nothing -> Nothing
  Just { head: c, tail: cs } ->
    Just
      $ Loc
          { node: c
          , before: r.node : r.before
          , after: cs
          , parents: r.parents
          }

-- -- | Move the cursor to the previous sibling.
prev ∷ ∀ a. Loc a -> Maybe (Loc a)
prev (Loc r) = case uncons r.before of
  Nothing -> Nothing
  Just { head: c, tail: cs } ->
    Just
      $ Loc
          { node: c
          , before: cs
          , after: r.node : r.after
          , parents: r.parents
          }

-- -- | Move the cursor to the first sibling.
first ∷ ∀ a. Loc a -> Loc a
first l@(Loc r) = case uncons r.before of
  Nothing -> l
  Just { head: c, tail: cs } ->
    Loc
      $
        { node: c
        , before: []
        , after: (reverse cs) <> r.after
        , parents: r.parents
        }

-- -- | Move the cursor to the last sibling.
last ∷ ∀ a. Loc a -> Loc a
last l@(Loc r) = case uncons (reverse r.after) of
  Nothing -> l
  Just { head: c, tail: cs } ->
    Loc
      $
        { node: c
        , before: cs <> r.node : r.before
        , after: []
        , parents: r.parents
        }

-- -- | Move the cursor to the parent `Node`.
up ∷ ∀ a. Loc a -> Maybe (Loc a)
up l@(Loc r) = case uncons r.parents of
  Nothing -> Nothing
  Just { head: p, tail: ps } ->
    Just
      $ Loc
          { node: (value p) :< (siblings l)
          , before: before p
          , after: after p
          , parents: ps
          }

-- | Move the cursor to the root of the tree.
root ∷ ∀ a. Loc a -> Loc a
root l = case up l of
  Nothing -> l
  Just p -> root p

-- | Move the cursor to the first child of the current `Node`.
firstChild ∷ ∀ a. Loc a -> Maybe (Loc a)
firstChild n = case uncons (children n) of
  Nothing -> Nothing
  Just { head: c, tail: cs } ->
    Just
      $ Loc
          { node: c
          , before: []
          , after: cs
          , parents: n : (parents n)
          }

-- | Move the cursor to the first child of the current `Node`.
down ∷ ∀ a. Loc a -> Maybe (Loc a)
down = firstChild

-- | Move the cursor to the last child of the current `Node`.
lastChild ∷ ∀ a. Loc a -> Maybe (Loc a)
lastChild p = last <$> down p

-- | Move the cursor to a specific sibling by it's index.
siblingAt ∷ ∀ a. Int -> Loc a -> Maybe (Loc a)
siblingAt i l@(Loc r) = case up l of
  Nothing -> Nothing
  Just p -> case (children p) !! i of
    Nothing -> Nothing
    Just c ->
      let
        before' = reverse $ take i (children p)
        after' = drop (i + 1) (children p)
      in
        Just
          $ Loc
              { node: c
              , before: before'
              , after: after'
              , parents: r.parents
              }

-- | Move the cursor to a specific child of the current `Node` by it's index.
childAt ∷ ∀ a. Int -> Loc a -> Maybe (Loc a)
childAt i p = (firstChild p) >>= (siblingAt i)

-- | Retrieve the `Tree` representation, i.e., returns the root `Node` of the
-- | current tree.
toTree ∷ ∀ a. Loc a -> Tree a
toTree = node <<< root

-- | Get a `Loc`ation representation from a given `Tree`.
fromTree ∷ ∀ a. Tree a -> Loc a
fromTree n =
  Loc
    { node: n
    , before: []
    , after: []
    , parents: []
    }

-- | Set the `Node` at the current position.
setNode ∷ ∀ a. Tree a -> Loc a -> Loc a
setNode a (Loc r) =
  Loc
    { node: a
    , before: r.before
    , after: r.after
    , parents: r.parents
    }

-- | Set the `Node` at the current position.
modifyNode ∷ ∀ a. (Tree a -> Tree a) -> Loc a -> Loc a
modifyNode f (Loc r) =
  Loc
    { node: f r.node
    , before: r.before
    , after: r.after
    , parents: r.parents
    }

-- | Set the value of the current `Node`.
setValue ∷ ∀ a. a -> Loc a -> Loc a
setValue a l = setNode (setNodeValue a (node l)) l

-- | Modify the value of the current `Node`.
modifyValue ∷ ∀ a. (a -> a) -> Loc a -> Loc a
modifyValue f l = setNode (modifyNodeValue f (node l)) l

-- -- insert and delete nodes
-- | Insert a node after the current position, and move cursor to the new node.
insertAfter ∷ ∀ a. Tree a -> Loc a -> Loc a
insertAfter n l =
  Loc
    { node: n
    , after: after l
    , before: (node l) : (before l)
    , parents: parents l
    }

-- | Insert a node before the current position, and move cursor to the new node.
insertBefore ∷ ∀ a. Tree a -> Loc a -> Loc a
insertBefore n l =
  Loc
    { node: n
    , after: (node l) : (after l)
    , before: before l
    , parents: parents l
    }

-- | Insert a node as a child to  the current node, and move cursor to the new node.
insertChild ∷ ∀ a. Tree a -> Loc a -> Loc a
insertChild n l = case down l of
  Just c -> insertAfter n c
  Nothing ->
    Loc
      { node: n
      , after: []
      , before: []
      , parents: l : (parents l)
      }

-- | Delete the node in the current position.
delete ∷ ∀ a. Loc a -> Loc a
delete l@(Loc r) = case uncons r.after of
  Just { head: c, tail: cs } ->
    Loc
      { node: c
      , before: r.before
      , after: cs
      , parents: r.parents
      }
  Nothing -> case uncons r.before of
    Just { head: c, tail: cs } ->
      Loc
        { node: c
        , before: cs
        , after: r.after
        , parents: r.parents
        }
    Nothing -> case uncons r.parents of
      Nothing -> l
      Just { head: c } ->
        Loc
          { node: mkTree (value c) []
          , before: before c
          , after: after c
          , parents: parents c
          }

-- Searches
-- | Search down and to the right for the first occurence where the given predicate is true and return the Loc
findDownWhere ∷ ∀ a. (a -> Boolean) -> Loc a -> Maybe (Loc a)
findDownWhere predicate loc
  | predicate $ value loc = Just loc

findDownWhere predicate loc = lookNext <|> lookDown
  where
  lookNext = next loc >>= findDownWhere predicate

  lookDown = down loc >>= findDownWhere predicate

-- | Search for the first occurence of the value `a` downwards and to the right.
findDown ∷ ∀ a. Eq a => a -> Loc a -> Maybe (Loc a)
findDown a = findDownWhere (_ == a)

-- | Search to the left and up for the first occurence where the given predicate is true and return the Loc
findUpWhere ∷ ∀ a. (a -> Boolean) -> Loc a -> Maybe (Loc a)
findUpWhere predicate loc
  | predicate $ value loc = Just loc

findUpWhere predicate loc = lookPrev <|> lookUp
  where
  lookPrev = prev loc >>= findUpWhere predicate

  lookUp = up loc >>= findUpWhere predicate

-- | Search for the first occurence of the value `a` upwards and to the left,
findUp ∷ ∀ a. Eq a => a -> Loc a -> Maybe (Loc a)
findUp a = findUpWhere (_ == a)

-- | Search from the root of the mkTree for the first occurrence where the given predicate is truen and return the Loc
findFromRootWhere ∷ ∀ a. (a -> Boolean) -> Loc a -> Maybe (Loc a)
findFromRootWhere predicate loc
  | predicate $ value loc = Just loc

findFromRootWhere predicate loc = findDownWhere predicate $ root loc

-- | Search for the first occurence of the value `a` starting from the root of
-- | the tree.
findFromRoot ∷ ∀ a. Eq a => a -> Loc a -> Maybe (Loc a)
findFromRoot a = findFromRootWhere (_ == a)

-- | flattens the Tree into a Array depth first.
flattenLocDepthFirst ∷ ∀ a. Loc a -> Array (Loc a)
flattenLocDepthFirst loc = loc : (go loc)
  where
  go ∷ Loc a -> Array (Loc a)
  go loc' =
    let
      downs = goDir loc' down
      nexts = goDir loc' next
    in
      downs <> nexts

  goDir ∷ Loc a -> (Loc a -> Maybe (Loc a)) -> Array (Loc a)
  goDir loc' dirFn = case (dirFn loc') of
    Just l -> l : go l
    Nothing -> []

-- Setters and Getters
node ∷ ∀ a. Loc a -> Tree a
node (Loc r) = r.node

value ∷ ∀ a. Loc a -> a
value = head <<< node

before ∷ ∀ a. Loc a -> Forest a
before (Loc r) = r.before

after ∷ ∀ a. Loc a -> Forest a
after (Loc r) = r.after

parents ∷ ∀ a. Loc a -> Array (Loc a)
parents (Loc r) = r.parents

children ∷ ∀ a. Loc a -> Forest a
children = tail <<< node

siblings ∷ ∀ a. Loc a -> Forest a
siblings (Loc r) = (reverse r.before) <> (r.node : r.after)
