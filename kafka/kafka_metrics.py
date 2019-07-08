from jmxquery import JMXConnection, JMXQuery

jmxConnection = JMXConnection("service:jmx:rmi:///jndi/rmi://127.0.0.1:9099/jmxrmi")
jmxQuery = [JMXQuery("kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions",
metric_name="kafka_{type}_{name}")]
metrics = jmxConnection.query(jmxQuery)
for metric in metrics:
  if metric.value == 0:
    print(f"WARN: UnderReplicatedPartitions > 0, value is ", metric.value )
    exit(1)
  print(f'{metric.metric_name}<{metric.metric_labels}> == {metric.value}')
