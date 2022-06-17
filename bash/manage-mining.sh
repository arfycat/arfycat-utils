#!/usr/bin/env bash
set -e -u -o pipefail

KWH_PRICE="$(cat elec-price.txt)"
MINING_WPH="$(cat mining-eth-wph.txt)"
MINING_MHS="$(cat mining-eth-mhs.txt)"

COIN_PRICE="$(curl -sS "https://api.coinbase.com/v2/prices/ETH-USD/spot" | jq -r ".data.amount")"
echo "ETH->USD = ${COIN_PRICE}"

MINING_GHS_DAILY_REWARD="$(curl -sS "https://api.flexpool.io/v2/pool/dailyRewardPerGigahashSec?coin=ETH" | jq -r ".result")"
WEI2ETH="0.000000000000000001"

MINING_USD_DAY="$(jq -n "${MINING_GHS_DAILY_REWARD} * ${WEI2ETH} * (${MINING_MHS}/1000) * ${COIN_PRICE}")"
echo "Mining USD/day = ${MINING_USD_DAY}"

ELEC_USD_DAY="$(jq -n "${MINING_WPH} * 24 / 1000 * ${KWH_PRICE} / 100")"
echo "Electricity USD/day = ${ELEC_USD_DAY}"
