extends RefCounted

const SAVE_PATH := "user://missions.cfg"


static func balance(file: ConfigFile) -> int:
	return int(file.get_value("wallet", "rubles", 0))


static func credit_once(file: ConfigFile, receipt: String, amount: int) -> int:
	if amount <= 0 or file.has_section_key("wallet_receipts", receipt):
		return 0
	file.set_value("wallet_receipts", receipt, amount)
	file.set_value("wallet", "rubles", balance(file) + amount)
	return amount


static func save(file: ConfigFile, path: String) -> Error:
	var temporary := path + ".tmp"
	var error := file.save(temporary)
	if error != OK:
		return error
	return DirAccess.rename_absolute(temporary, path)
