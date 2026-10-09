"""عميل البلوكشين — ختم جذر Merkle لسلسلة الحفظ

وضعان:
1. **On-chain**: عند ضبط BLOCKCHAIN_RPC_URL + PRIVATE_KEY + CONTRACT_ADDRESS —
   معاملة حقيقية على شبكة الاختبار (Sepolia).
2. **Offline Merkle** (الافتراضي): حساب الجذر محلياً وحفظه — قابل للتحقق بإعادة
   الحساب، ويُرسل للشبكة لاحقاً عند توفر الإعدادات.

web3 تُستورد داخل الدوال فقط — التطبيق يعمل دون تثبيتها في وضع offline.
"""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from app.core.config import get_settings
import logging

logger = logging.getLogger("napex.chain")

_ABI_PATH = Path(__file__).resolve().parents[3] / "contracts" / "EvidenceRegistry.abi.json"


def build_merkle_root(hashes: list[str]) -> str:
    """شجرة Merkle من هاشات سلسلة الحفظ (تكرار الأخير إن كان العدد فردياً)"""
    if not hashes:
        return ""
    level = [bytes.fromhex(h) for h in hashes]
    while len(level) > 1:
        if len(level) % 2 == 1:
            level.append(level[-1])
        level = [
            hashlib.sha256(level[i] + level[i + 1]).digest()
            for i in range(0, len(level), 2)
        ]
    return level[0].hex()


def _load_abi() -> list:
    return json.loads(_ABI_PATH.read_text(encoding="utf-8"))["abi"]


def anchor_on_chain(batch_id: str, merkle_root: str) -> dict:
    """ختم الجذر على الشبكة — يُعيد tx_hash/block أو يرفع استثناء"""
    settings = get_settings()
    if not (settings.blockchain_rpc_url and settings.blockchain_private_key
            and settings.blockchain_contract_address):
        raise RuntimeError("BLOCKCHAIN_RPC_URL غير مهيأ")

    from web3 import Web3

    w3 = Web3(Web3.HTTPProvider(settings.blockchain_rpc_url))
    account = w3.eth.account.from_key(settings.blockchain_private_key)
    contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.blockchain_contract_address),
        abi=_load_abi(),
    )

    tx = contract.functions.anchor(
        batch_id, bytes.fromhex(merkle_root)
    ).build_transaction(
        {
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200_000,
            "gasPrice": w3.eth.gas_price,
            "chainId": settings.blockchain_chain_id,
        }
    )
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

    return {
        "tx_hash": tx_hash.hex(),
        "block_number": receipt["blockNumber"],
        "chain_id": settings.blockchain_chain_id,
    }


def verify_on_chain(batch_id: str, expected_root: str) -> dict:
    """قراءة الجذر من الشبكة ومطابقته — عامة وبلا مصادقة"""
    settings = get_settings()
    if not settings.blockchain_rpc_url or not settings.blockchain_contract_address:
        return {"on_chain": False, "reason": "الشبكة غير مهيأة"}

    from web3 import Web3

    w3 = Web3(Web3.HTTPProvider(settings.blockchain_rpc_url))
    contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.blockchain_contract_address),
        abi=_load_abi(),
    )
    anchored_at = contract.functions.anchoredAt(batch_id).call()
    on_chain = anchored_at != 0
    return {
        "on_chain": on_chain,
        "matches": on_chain
        and contract.functions.roots(batch_id).call()[0]
        == bytes.fromhex(expected_root),
        "anchored_at": (
            datetime.fromtimestamp(anchored_at, tz=timezone.utc).isoformat()
            if on_chain
            else None
        ),
    }


def safe_anchor_on_chain(batch_id: str, merkle_root: str) -> dict | None:
    """ختم آمن — لا يرفع استثناء أبداً (البلوكشين تعزيز وليس شرط تشغيل)"""
    try:
        result = anchor_on_chain(batch_id, merkle_root)
        logger.info("Anchored %s on-chain: %s", batch_id, result.get("tx_hash"))
        return result
    except Exception as exc:  # noqa: BLE001
        logger.warning("On-chain anchor failed (offline kept): %s", exc)
        return None
