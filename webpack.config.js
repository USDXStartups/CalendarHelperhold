const webpack = require('webpack')
const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')

module.exports = {
  context: __dirname,
  entry: ['babel-polyfill', './app/js/browser-entry.jsx'],
  output: {
    path: path.join(__dirname, '/public/js'),
    filename: 'bundle.[chunkhash].js',
    publicPath: '/public/js/'
  },
  resolve: {
    extensions: ['', '.js', '.jsx', '.json']
  },
  stats: {
    colors: true,
    reasons: true,
    chuncks: true
  },
  module: {
    preLoaders: [{
      test: /\.jsx?$/,
      loader: 'eslint-loader',
      exclude: /node_modules/
    }],
    loaders: [{
      test: /\.jsx?$/,
      loader: 'babel-loader',
      exclude: /node_modules/
    }, {
      test: /\.json$/,
      loader: 'json-loader',
      exclude: /node_modules/
    }, {
      test: /\.jpe?g$|\.gif$|\.svg$|\.png$/i,
      loader: 'file-loader?name=../imgs/[sha512:hash:base64:7].[ext]',
      exclude: /node_modules/
    }]
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './public/index.html',
      filename: '../index.html',
      inject: true
    }),
    new webpack.DefinePlugin({
      'process.env': {
        'NODE_ENV': JSON.stringify('production')
      }
    }),
    new webpack.optimize.UglifyJsPlugin({
      compress: {
        warnings: true
      }
    })
  ]
}
