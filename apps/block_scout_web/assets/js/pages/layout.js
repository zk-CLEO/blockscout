import axios from 'axios'
import $ from 'jquery'
import Cookie from 'js-cookie'
import Web3 from 'web3'
$(document).click(function (event) {
  const clickover = $(event.target)
  const _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})

const topConnectWallet = '[top-connect-wallet]'
const topDisconnectWallet = '[top-disconnect-wallet]'
const showWallet = '[show-wallet]'

const $topConnectWallet = $('[top-connect-wallet]')
const $topDisconnectWallet = $('[top-disconnect-wallet]')

window.ethereum.on('disconnect', () => {
  Cookie.remove('authorization_wallet')
  Cookie.remove('authorization_token')
  document.querySelector(topDisconnectWallet)?.classList.add('hidden')
  document.querySelector(showWallet)?.classList.add('hidden')
  document.querySelector(topConnectWallet)?.classList.remove('hidden')
  location.reload()
})

window.ethereum.on('accountsChanged', function (accounts) {
  Cookie.remove('authorization_wallet')
  Cookie.remove('authorization_token')
  document.querySelector(topDisconnectWallet)?.classList.add('hidden')
  document.querySelector(showWallet)?.classList.add('hidden')
  document.querySelector(topConnectWallet)?.classList.remove('hidden')
  location.reload()
})

const checkConnectWallet = async () => {
  const walletConnect = await getCurrentAccount()
  const authorizationWallet = Cookie.get('authorization_wallet')
  const authorizationToken = Cookie.get('authorization_token')
  if (
    walletConnect &&
    authorizationWallet &&
    authorizationToken
  ) {
    document.querySelector(topDisconnectWallet)?.classList.remove('hidden')
    document.querySelector(showWallet)?.classList.remove('hidden')
    if (document.querySelector(showWallet)) {
      const walletConnectString = walletConnect.toString()
      const truncatedString =
        walletConnectString.substring(0, 8) +
        '...' +
        walletConnectString.substring(walletConnectString.length - 5)
      document.querySelector(showWallet).innerHTML = truncatedString
    }
    document.querySelector(topConnectWallet)?.classList.add('hidden')
  } else {
    Cookie.remove('authorization_wallet')
    Cookie.remove('authorization_token')
    document.querySelector(topDisconnectWallet)?.classList.add('hidden')
    document.querySelector(showWallet)?.classList.add('hidden')
    document.querySelector(topConnectWallet)?.classList.remove('hidden')
  }
}
setInterval(() => {
  checkConnectWallet()
}, [1000])

$topConnectWallet.on('click', async (_event) => {
  try {
    await window.ethereum.request({ method: 'eth_requestAccounts' })
    const walletConnect = await getCurrentAccount()

    if (walletConnect) {
      axios
        .post('http://localhost:8080/as-authorization/secret-nonce', {
          wallet_address: walletConnect
        })
        .then(async (res) => {
          const message = res.data.data.secret_nonce
          if (message) {
            const web3 = new Web3(window.ethereum)
            const signData = JSON.stringify({
              domain: {
                chainId: 1302,
                name: 'CLEO BlockScout',
                version: '1'
              },
              message: {
                contents: message,
                attachedMoneyInEth: 0
              },
              primaryType: 'BlockScout',
              types: {
                // This refers to the domain the contract is hosted on.
                EIP712Domain: [
                  { name: 'name', type: 'string' },
                  { name: 'version', type: 'string' },
                  { name: 'chainId', type: 'uint256' }
                ],
                BlockScout: [
                  { name: 'contents', type: 'string' }
                ]
              }
            })
            web3.currentProvider.sendAsync({
              method: 'eth_signTypedData_v4',
              params: [walletConnect, signData],
              from: walletConnect
            }, (_, res) => {
              axios.post('http://localhost:8080/as-authorization/signature-verified', {
                wallet_address: walletConnect,
                signature: res.result
              }).then(res => {
                Cookie.set('authorization_wallet', walletConnect, { expires: 1 })
                Cookie.set(
                  'authorization_token',
                  res.data.data.token,
                  { expires: 1 }
                )
                location.reload()
              })
            })
          }
        })
        .catch(() => {})
    }

    document.querySelector(topDisconnectWallet)?.classList.remove('hidden')
    document.querySelector(showWallet)?.classList.remove('hidden')
    if (document.querySelector(showWallet)) {
      const walletConnectString = walletConnect.toString()
      const truncatedString =
        walletConnectString.substring(0, 8) +
        '...' +
        walletConnectString.substring(walletConnectString.length - 5)
      document.querySelector(showWallet).innerHTML = truncatedString
    }
    document.querySelector(topConnectWallet)?.classList.add('hidden')
  } catch (error) {
    console.error('Error connecting wallet:', error)
  }
})

$topDisconnectWallet.on('click', async (_event) => {
  try {
    Cookie.remove('authorization_wallet')
    Cookie.remove('authorization_token')
    document.querySelector(topDisconnectWallet)?.classList.add('hidden')
    document.querySelector(showWallet)?.classList.add('hidden')
    document.querySelector(topConnectWallet)?.classList.remove('hidden')
    location.reload()
  } catch (error) {
    console.error('Error connecting wallet:', error)
  }
})

function getCurrentAccount () {
  return new Promise((resolve, reject) => {
    window.ethereum
      .request({ method: 'eth_accounts' })
      .then((accounts) => {
        const account = accounts[0] ? accounts[0].toLowerCase() : null
        resolve(account)
      })
      .catch((err) => {
        reject(err)
      })
  })
}

const search = (value) => {
  if (value) {
    window.location.href = `/search?q=${value}`
  }
}

$(document).on('keyup', function (event) {
  if (event.key === '/') {
    $('.main-search-autocomplete').trigger('focus')
  }
})

$('.main-search-autocomplete').on('keyup', function (event) {
  if (event.key === 'Enter') {
    let selected = false
    $('li[id^="autoComplete_result_"]').each(function () {
      if ($(this).attr('aria-selected')) {
        selected = true
      }
    })
    if (!selected) {
      search(event.target.value)
    }
  }
})

$('#search-icon').on('click', function (event) {
  const value =
    $('.main-search-autocomplete').val() ||
    $('.main-search-autocomplete-mobile').val()
  search(value)
})

$('.main-search-autocomplete').on('focus', function (_event) {
  $('#slash-icon').hide()
  $('.search-control').addClass('focused-field')
})

$('.main-search-autocomplete').on('focusout', function (_event) {
  $('#slash-icon').show()
  $('.search-control').removeClass('focused-field')
})
