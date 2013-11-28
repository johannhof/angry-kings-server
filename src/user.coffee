User = mongoose.model 'User', mongoose.Schema({
  name: String,
  phoneID: String,
  won: Number,
  lost: Number
})

