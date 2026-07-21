# scripts/resources/ProvinceData.gd
class_name ProvinceData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var prosperity: int = 50
@export var loyalty: int = 80
@export var religion: float = 50.0  # 0 = pohanská, 100 = kresťanská
@export var owner_faction: String = "moravia"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"prosperity": prosperity,
		"loyalty": loyalty,
		"religion": religion,
		"owner_faction": owner_faction
	}


static func from_dict(data: Dictionary) -> ProvinceData:
	var p := ProvinceData.new()
	p.id = str(data.get("id", ""))
	p.name = str(data.get("name", ""))
	p.prosperity = int(data.get("prosperity", 50))
	p.loyalty = int(data.get("loyalty", 80))
	p.religion = float(data.get("religion", 50.0))
	p.owner_faction = str(data.get("owner_faction", "moravia"))
	return p
