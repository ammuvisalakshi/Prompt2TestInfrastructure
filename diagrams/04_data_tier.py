from diagrams import Diagram, Cluster, Edge
from diagrams.aws.database import Aurora, Dynamodb
from diagrams.aws.compute import Lambda
from diagrams.aws.ml import Bedrock
from diagrams.aws.security import Cognito, SecretsManager
from diagrams.aws.management import SystemsManager

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/04_data_tier",
    direction="LR",
    outformat="png",
    graph_attr={
        "fontsize": "22",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "1.0",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "2.5",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "Data & Configuration Tier",
    },
    node_attr={
        "fontsize": "12",
        "fontcolor": "#232f3e",
        "fontname": "Arial",
        "width": "1.5",
        "height": "1.5",
    },
    edge_attr={
        "penwidth": "2.0",
        "color": "#545b64",
        "arrowsize": "1.0",
    },
):
    lambda_fn = Lambda("Lambda")
    bedrock = Bedrock("Bedrock\nAgentCore")
    cognito = Cognito("Frontend\n(Cognito Auth)")

    with Cluster("Primary Database", graph_attr={"bgcolor": "#eaf5ea", "pencolor": "#82b882", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        aurora = Aurora("Aurora Serverless v2\nPostgreSQL 16\n+ pgvector\n0-4 ACU, auto-pause")

    with Cluster("Configuration Store", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        dynamo = Dynamodb("DynamoDB\nprompt2test-config\n(pk / sk)")

    with Cluster("Secrets & Parameters", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        ssm = SystemsManager("SSM\nParameter Store\n(Aurora ARNs)")
        secrets = SecretsManager("Secrets Manager\n(DB credentials,\ntest accounts)")

    lambda_fn >> Edge(color="#16a34a", style="solid", label="test cases\n+ results", fontsize="10", fontcolor="#545b64") >> aurora
    cognito >> Edge(color="#2563eb", style="solid", label="service config\n+ environments", fontsize="10", fontcolor="#545b64") >> dynamo
    bedrock >> Edge(color="#16a34a", style="dashed", label="plans + vectors", fontsize="10", fontcolor="#545b64") >> aurora
    lambda_fn >> Edge(color="#b45309", style="dashed", label="reads", fontsize="10", fontcolor="#545b64") >> ssm
    lambda_fn >> Edge(color="#b45309", style="dashed", label="reads", fontsize="10", fontcolor="#545b64") >> secrets
