extends Node

## Market stub. Trading is deferred. Prices stay at the catalog base until then.


func price(_system_id: String, commodity_id: String) -> int:
	return Galaxy.commodity_base_price(commodity_id)
