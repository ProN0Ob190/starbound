function update(store)
  if store.recoil then
    if not store.recoilTime then
      store.recoilTime = store.recoil
    end
    vremove(store, "recoil")
  end
  return store
end
