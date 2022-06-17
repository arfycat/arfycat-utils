#!/usr/bin/env bash
set -e -u -o pipefail

KWH_PRICE="$(cat "${HOME}/elec-price.txt")"

eth() {
  echo '--------------------------------------------------------------------------------'
  echo "ETH"
  echo '--------------------------------------------------------------------------------'
  
  local ETH_WPH="$(cat "${HOME}/mining-eth-wph.txt")"
  local ETH_MHS="$(cat "${HOME}/mining-eth-mhs.txt")"

  local COIN_PRICE="$(curl -sS "https://api.coinbase.com/v2/prices/ETH-USD/spot" | jq -r ".data.amount")"
  echo "ETH->USD = ${COIN_PRICE}"

  local ETH_GHS_DAILY_REWARD="$(curl -sS "https://api.flexpool.io/v2/pool/dailyRewardPerGigahashSec?coin=ETH" | jq -r ".result")"
  local WEI2ETH="0.000000000000000001"

  local MINING_USD_DAY="$(jq -n "${ETH_GHS_DAILY_REWARD} * ${WEI2ETH} * (${ETH_MHS}/1000) * ${COIN_PRICE}")"
  echo "Mining USD/day = ${MINING_USD_DAY}"

  local ELEC_USD_DAY="$(jq -n "${ETH_WPH} * 24 / 1000 * ${KWH_PRICE} / 100")"
  echo "Electricity USD/day = ${ELEC_USD_DAY}"
  echo
}

xch() {
  echo '--------------------------------------------------------------------------------'
  echo "XCH"
  echo '--------------------------------------------------------------------------------'
  
  local XCH_WPH="$(cat "${HOME}/mining-xch-wph.txt")"
  local XCH_TBS="$(cat "${HOME}/mining-xch-tbs.txt")"

  local COIN_PRICE="$(curl -sS "https://api.coinbase.com/v2/exchange-rates?currency=XCH" | jq -r ".data.rates.USD")"
  echo "XCH->USD = ${COIN_PRICE}"

  local XCH_GHS_DAILY_REWARD="$(curl -sS "https://api.flexpool.io/v2/pool/dailyRewardPerGigahashSec?coin=XCH" | jq -r ".result")"
  local GHS2XCH="0.000000001"

  local MINING_USD_DAY="$(jq -n "${XCH_GHS_DAILY_REWARD} * ${GHS2XCH} * ${XCH_TBS} * ${COIN_PRICE}")"
  echo "Mining USD/day = ${MINING_USD_DAY}"

  local ELEC_USD_DAY="$(jq -n "${XCH_WPH} * 24 / 1000 * ${KWH_PRICE} / 100")"
  echo "Electricity USD/day = ${ELEC_USD_DAY}"
  echo
}

RET=0

if [[ -f "${HOME}/mining-eth-wph.txt" && -f "${HOME}/mining-eth-mhs.txt" ]]; then
  eth || RET=$?
fi
if [[ -f "${HOME}/mining-xch-wph.txt" && -f "${HOME}/mining-xch-tbs.txt" ]]; then
  xch || RET=$?
fi

exit $RET
