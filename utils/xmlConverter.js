const {json2xml} = require("xml-js");

const convertToXml = (data) => {
  const options = {compact: true, ignoreComment: true, spaces: 4};
  return json2xml(data, options);
};

module.exports = {
  convertToXml,
};
