///|
/// A single path parameter extracted from the URL.
pub struct Param {
  key : String
  value : String
} derive(Eq, Show)

///|
/// Collection of path parameters extracted from the URL.
/// Provides efficient lookup by parameter name.
pub struct Params {
  items : Array[Param]
} derive(Eq, Show)

///|
/// Create an empty Params collection.
pub fn Params::new() -> Params {
  { items: [] }
}

///|
/// Create Params from an array of key-value tuples.
pub fn Params::from_array(arr : Array[(String, String)]) -> Params {
  let items = arr.map(fn(pair) { { key: pair.0, value: pair.1 } })
  { items, }
}

///|
/// Get a parameter value by its name.
/// Returns None if the parameter does not exist.
pub fn Params::get(self : Params, name : String) -> String? {
  for param in self.items {
    if param.key == name {
      return Some(param.value)
    }
  }
  None
}

///|
/// Check if a parameter exists.
pub fn Params::has(self : Params, name : String) -> Bool {
  self.get(name) is Some(_)
}

///|
/// Get the number of parameters.
pub fn Params::length(self : Params) -> Int {
  self.items.length()
}

///|
/// Check if there are no parameters.
pub fn Params::is_empty(self : Params) -> Bool {
  self.items.is_empty()
}

///|
/// Add a parameter to the collection.
pub fn Params::add(self : Params, key : String, value : String) -> Unit {
  self.items.push({ key, value })
}
