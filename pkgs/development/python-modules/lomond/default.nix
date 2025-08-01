{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  pythonAtLeast,
  pythonOlder,

  # runtime
  six,

  # tests
  freezegun,
  pytest-mock,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "lomond";
  version = "0.3.3";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "wildfoundry";
    repo = "dataplicity-${pname}";
    rev = "b30dad3cc38d5ff210c5dd01f8c3c76aa6c616d1";
    sha256 = "0lydq0imala08wxdyg2iwhqa6gcdrn24ah14h91h2zcxjhjk4gv8";
  };

  postPatch = ''
    substituteInPlace setup.py \
      --replace "'pytest-runner'" ""
  '';

  propagatedBuildInputs = [ six ];

  nativeCheckInputs = [
    freezegun
    pytest-mock
    pytestCheckHook
  ];

  disabledTests = [
    # Makes HTTP requests
    "test_proxy"
    "test_live"
  ]
  ++ lib.optionals (pythonAtLeast "3.12") [
    # https://github.com/wildfoundry/dataplicity-lomond/issues/91
    "test_that_on_ping_responds_with_pong"
  ];

  disabledTestPaths = [
    # requires tornado_4, which is not compatible with python3.10
    "tests/test_integration.py"
  ];

  meta = with lib; {
    description = "Websocket Client Library";
    homepage = "https://github.com/wildfoundry/dataplicity-lomond";
    license = licenses.bsd3;
    maintainers = with maintainers; [ jamiemagee ];
  };
}
